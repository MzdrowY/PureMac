import Foundation
import AppKit

struct InstalledApp: Identifiable, Hashable {
    let id: UUID
    let appName: String
    let bundleIdentifier: String
    let path: URL
    let icon: NSImage
    let size: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }
}

final class AppInfoFetcher {
    static let shared = AppInfoFetcher()
    private let fileManager = FileManager.default

    private static let protectedBundleIDs: Set<String> = [
        "com.apple.Safari", "com.apple.finder", "com.apple.AppStore",
        "com.apple.systempreferences", "com.apple.Terminal",
        "com.apple.ActivityMonitor", "com.apple.dt.Xcode",
        "com.apple.mail", "com.apple.iCal", "com.apple.AddressBook",
        "com.apple.Preview", "com.apple.TextEdit", "com.apple.calculator",
        "com.apple.MobileSMS", "com.apple.FaceTime", "com.apple.Music",
        "com.apple.TV", "com.apple.Podcasts", "com.apple.News",
        "com.apple.Maps", "com.apple.Photos", "com.apple.Notes",
        "com.apple.reminders", "com.apple.Stocks", "com.apple.Home",
        "com.apple.weather", "com.apple.clock", "com.apple.Passwords",
    ]

    private init() {}

    func fetchInstalledApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        var seenBundleIDs: Set<String> = []

        let searchPaths = [
            "/Applications",
            "\(home)/Applications",
            "/System/Applications",
        ]

        for searchPath in searchPaths {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }

                // Skip subdirectories inside .app bundles
                enumerator.skipDescendants()

                // Skip system/protected apps
                if url.path.hasPrefix("/System") { continue }

                guard let app = loadAppInfo(from: url),
                      !seenBundleIDs.contains(app.bundleIdentifier),
                      !Self.protectedBundleIDs.contains(app.bundleIdentifier) else { continue }

                seenBundleIDs.insert(app.bundleIdentifier)
                apps.append(app)
            }
        }

        return apps.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    /// Build an `InstalledApp` from a single bundle URL. Used by the Finder
    /// Services handler ("Uninstall with PureMac") to resolve a right-clicked
    /// .app into the uninstaller without re-scanning every app. Enforces the
    /// same protections as the full scan: no /System apps, and no protected
    /// Apple bundle IDs (Safari, Mail, Xcode, App Store, …) — so a right-click
    /// can never route a system app into the uninstaller.
    func fetchApp(at url: URL) -> InstalledApp? {
        guard url.pathExtension == "app", !url.path.hasPrefix("/System") else { return nil }
        guard let app = loadAppInfo(from: url),
              !Self.protectedBundleIDs.contains(app.bundleIdentifier) else { return nil }
        return app
    }

    private func loadAppInfo(from url: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: url) else { return nil }

        let bundleID = bundle.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
        let appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)

        let size = appSize(at: url)

        return InstalledApp(
            id: UUID(),
            appName: appName,
            bundleIdentifier: bundleID,
            path: url,
            icon: icon,
            size: size
        )
    }

    private func appSize(at url: URL) -> Int64 {
        // totalFileAllocatedSizeKey on a directory URL returns only the
        // directory inode (~4 KB on APFS), not the recursive sum - the
        // previous fast-path returned that and exited, causing app sizes
        // to display as ~4 KB regardless of bundle contents. Always
        // enumerate the bundle contents and sum.
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey, .isSymbolicLinkKey]) else { continue }
            // Skip symlinks so we don't double-count or follow links out of
            // the bundle. Skip directories so we only count regular file
            // payload.
            if values.isSymbolicLink == true { continue }
            guard values.isRegularFile == true else { continue }
            if let allocated = values.totalFileAllocatedSize {
                total += Int64(allocated)
            } else if let allocated = values.fileAllocatedSize {
                total += Int64(allocated)
            }
        }
        return total
    }
}
