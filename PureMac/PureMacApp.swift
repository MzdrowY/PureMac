import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        // Touch TCC-protected paths so macOS registers PureMac in the
        // Full Disk Access pane on first launch (fixes issue #75).
        FullDiskAccessManager.shared.triggerRegistration()
        // Register the Finder Services provider so "Uninstall with PureMac"
        // appears when an .app bundle is right-clicked (issue #109).
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    /// Finder Services entry point. Declared in Info.plist as NSMessage
    /// `uninstallApp`; receives the right-clicked .app via the pasteboard and
    /// hands it to AppState through a notification. Brings PureMac forward so
    /// the user lands on the uninstall scan.
    @objc func uninstallApp(_ pboard: NSPasteboard,
                            userData: String?,
                            error: AutoreleasingUnsafeMutablePointer<NSString>?) {
        let urls = (pboard.readObjects(forClasses: [NSURL.self],
                                       options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        guard let appURL = urls.first(where: { $0.pathExtension == "app" }) else {
            error?.pointee = "Select an application (.app) to uninstall." as NSString
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        // Buffer the path for the cold-launch case (AppState may not exist yet,
        // and NotificationCenter does not replay); AppState drains it in init.
        ExternalUninstallBuffer.pendingPath = appURL.path
        NotificationCenter.default.post(
            name: .pureMacExternalUninstall,
            object: nil,
            userInfo: ["path": appURL.path]
        )
    }
}

@main
struct PureMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var theme = ThemeManager.shared
    @AppStorage("PureMac.OnboardingComplete") private var onboardingComplete = false

    init() {
        // Enter CLI mode only when the first arg is a known command. Xcode and
        // LaunchServices inject args like -NSDocumentRevisionsDebugMode and
        // -psn_<pid> that must not be interpreted as CLI commands.
        if let first = CommandLine.arguments.dropFirst().first,
           CLI.isKnownCommand(first) {
            CLI.run()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingComplete {
                    MainWindow()
                        .environmentObject(appState)
                        .frame(minWidth: 900, minHeight: 600)
                } else {
                    OnboardingView(isComplete: $onboardingComplete)
                }
            }
            .environmentObject(theme)
            .preferredColorScheme(theme.appearance.colorScheme)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1000, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Updates") {
                Button("Check for Updates") {
                    UpdateService.shared.checkForUpdates()
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
