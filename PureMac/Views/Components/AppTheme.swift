import SwiftUI

/// User-overridable appearance setting that lives independently of the system
/// preference, mirroring the prototype's titlebar light/dark toggle.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("PureMac.Appearance") private var rawValue: String = AppearanceMode.system.rawValue

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: rawValue) ?? .system }
        set { rawValue = newValue.rawValue; objectWillChange.send() }
    }
}

/// Centralized accent palette. One blue, one green for success, one orange
/// for warning, one red for destructive. Other tints exist for categorical
/// differentiation but the surface chrome only uses these four.
enum Tint {
    static let blue   = Color(red: 0.04, green: 0.52, blue: 1.00)
    static let green  = Color(red: 0.18, green: 0.78, blue: 0.47)
    static let orange = Color(red: 1.00, green: 0.58, blue: 0.04)
    static let purple = Color(red: 0.55, green: 0.32, blue: 0.87)
    static let pink   = Color(red: 1.00, green: 0.30, blue: 0.50)
    static let cyan   = Color(red: 0.30, green: 0.78, blue: 0.95)
    static let red    = Color(red: 1.00, green: 0.27, blue: 0.23)
    static let yellow = Color(red: 1.00, green: 0.78, blue: 0.04)
}

/// Tinted square icon container used in the sidebar and on dashboard cards.
/// Single muted fill, thin border. The tint identifies the category - it
/// doesn't need to glow.
struct IconTile: View {
    let systemName: String
    var tint: Color = Tint.blue
    var size: CGFloat = 26
    var corner: CGFloat = 7
    /// Retained for callsite compatibility; intentionally a no-op in the
    /// restrained design so call sites don't have to change.
    var glow: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(tint.opacity(0.14))
            Image(systemName: systemName)
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

/// Card surface. Flat fill, hairline border, single soft shadow. No accent
/// stripe by default — content hierarchy carries the meaning, not chrome.
struct CardSurface<Content: View>: View {
    var padding: CGFloat = 16
    /// Retained for callsite compatibility; the accent line is intentionally
    /// not rendered in the restrained design.
    var accent: Color? = nil
    var elevation: CardElevation = .standard
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(elevation.ambient), radius: elevation.ambientRadius, y: elevation.ambientY)
    }
}

enum CardElevation {
    case flat, standard, raised

    var ambient: Double {
        switch self {
        case .flat: return 0.0
        case .standard: return 0.04
        case .raised: return 0.07
        }
    }

    var ambientRadius: CGFloat {
        switch self {
        case .flat: return 0
        case .standard: return 4
        case .raised: return 10
        }
    }

    var ambientY: CGFloat {
        switch self {
        case .flat: return 0
        case .standard: return 1
        case .raised: return 3
        }
    }
}

/// Small status pill. Solid tint background at low opacity, no gradient.
struct StatusChip: View {
    let label: String
    var systemImage: String? = nil
    var tint: Color = Tint.blue

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.14)))
        .foregroundStyle(tint)
    }
}

/// Subtle hover/press feedback for tappable cards. Scale only — no glow.
struct PressableScale: ViewModifier {
    @State private var hovering = false
    @State private var pressing = false
    var hoverScale: CGFloat = 1.006

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressing ? 0.99 : (hovering ? hoverScale : 1.0))
            .animation(.easeOut(duration: 0.18), value: hovering)
            .animation(.easeOut(duration: 0.08), value: pressing)
            .onHover { hovering = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressing = true }
                    .onEnded { _ in pressing = false }
            )
    }
}

extension View {
    func pressable(hoverScale: CGFloat = 1.006) -> some View {
        modifier(PressableScale(hoverScale: hoverScale))
    }
}
