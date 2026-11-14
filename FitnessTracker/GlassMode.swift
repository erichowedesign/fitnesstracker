import SwiftUI

/// User-facing Liquid Glass appearance. Persisted; drives glass material + ink palette.
/// Clear = untinted clear glass. Dark = dark-tinted clear glass (still clear — not opaque regular).
enum GlassMode: String, CaseIterable, Identifiable, Codable, Hashable {
    case dark
    case clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Dark"
        case .clear: return "Clear"
        }
    }

    /// Maps to SwiftUI `Glass` (iOS 26/27 Liquid Glass).
    /// Public Glass: `regular` / `clear` + `tint` / `interactive`.
    /// Both modes stay on the **clear** path — Dark is dark-tinted clear, not opaque regular.
    /// - Clear → untinted clear
    /// - Dark → clear + subtle black tint (+ light underlay); denser than Clear, still see-through
    @available(iOS 26, *)
    func glass(interactive: Bool) -> Glass {
        let base: Glass
        switch self {
        case .dark:
            base = .clear.tint(Color.black.opacity(0.38))
        case .clear:
            base = .clear
        }
        return interactive ? base.interactive() : base
    }

    /// Soft fill under Dark clear glass only — keep it light so the wash still reads through.
    var glassUnderlay: Color? {
        switch self {
        case .dark:
            return Color.black.opacity(0.12)
        case .clear:
            return nil
        }
    }

    var palette: GlassPalette { GlassPalette(mode: self) }
}

/// Design-system inks / chrome for the active glass mode.
struct GlassPalette: Equatable {
    var mode: GlassMode

    /// Main titles, body, icons on content.
    var primary: Color
    /// Supporting copy.
    var secondary: Color
    /// Captions / hints.
    var tertiary: Color
    /// Unselected chrome glyphs (tab bar, menus).
    var chrome: Color
    /// Selected tab / accent.
    var accent: Color
    /// Soft fills / hairlines.
    var dim: Color
    /// Favorites heart (on).
    var heart: Color
    /// Color scheme for Liquid Glass / system materials — flips with Clear vs Dark.
    var colorScheme: ColorScheme
    /// Veil over the wash (unused for Clear/Dark; both keep wash visible).
    var washVeil: Color
    /// Soft tray fill under chrome glass (tab bar, etc.).
    var chromeTray: Color
    /// Selected tab / chrome pill fill.
    var chromePill: Color
    /// Unselected chrome glyphs use plusLighter in Dark.
    var chromePlusLighter: Bool

    init(mode: GlassMode) {
        self.mode = mode
        accent = Color(red: 0, green: 0.569, blue: 1)
        heart = .pink
        // Content sits on the wash with light ink in both modes.
        primary = Color(red: 0.961, green: 0.961, blue: 0.961)
        secondary = Color.white.opacity(0.85)
        tertiary = Color.white.opacity(0.72)
        chrome = Color(red: 0.961, green: 0.961, blue: 0.961)
        dim = Color.white.opacity(0.12)
        washVeil = .clear
        switch mode {
        case .clear:
            // Light scheme → buttons / tiles / nav resolve the clear path.
            colorScheme = .light
            chromeTray = Color.white.opacity(0.18)
            chromePill = Color.white.opacity(0.42)
            chromePlusLighter = false
        case .dark:
            // Dark scheme + soft dark tray — still translucent under clear glass.
            colorScheme = .dark
            chromeTray = Color.black.opacity(0.28)
            chromePill = Color.black.opacity(0.4)
            chromePlusLighter = true
        }
    }

    static let clear = GlassPalette(mode: .clear)
}

enum GlassInkLevel {
    case primary, secondary, tertiary, chrome
}

@Observable
final class GlassModeStore {
    private static let defaultsKey = "foundation.glassMode"

    var mode: GlassMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.defaultsKey) }
    }

    var palette: GlassPalette { mode.palette }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.defaultsKey) {
            if let saved = GlassMode(rawValue: raw) {
                mode = saved
            } else if raw == "light" {
                // Former Light option removed — land on Clear.
                mode = .clear
            } else {
                mode = .clear
            }
        } else {
            mode = .clear
        }
    }
}

private struct GlassModeEnvironmentKey: EnvironmentKey {
    static let defaultValue: GlassMode = .clear
}

private struct GlassPaletteEnvironmentKey: EnvironmentKey {
    static let defaultValue: GlassPalette = .clear
}

extension EnvironmentValues {
    var glassMode: GlassMode {
        get { self[GlassModeEnvironmentKey.self] }
        set { self[GlassModeEnvironmentKey.self] = newValue }
    }

    var glassPalette: GlassPalette {
        get { self[GlassPaletteEnvironmentKey.self] }
        set { self[GlassPaletteEnvironmentKey.self] = newValue }
    }
}

/// Applies the current glass mode via `.glassEffect`.
struct FoundationGlassModifier<S: Shape>: ViewModifier {
    var interactive: Bool
    var shape: S
    @Environment(\.glassMode) private var glassMode
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(iOS 26, *), !reduceTransparency {
            content
                .background {
                    if let underlay = glassMode.glassUnderlay {
                        shape.fill(underlay)
                    }
                }
                .glassEffect(glassMode.glass(interactive: interactive), in: shape)
        } else {
            content
                .background {
                    shape.fill(
                        glassMode == .dark
                            ? AnyShapeStyle(Color.black.opacity(0.28))
                            : AnyShapeStyle(Color.white.opacity(0.12))
                    )
                }
        }
    }
}

private struct GlassInkModifier: ViewModifier {
    var level: GlassInkLevel
    @Environment(\.glassPalette) private var palette

    func body(content: Content) -> some View {
        content.foregroundStyle(color)
    }

    private var color: Color {
        switch level {
        case .primary: return palette.primary
        case .secondary: return palette.secondary
        case .tertiary: return palette.tertiary
        case .chrome: return palette.chrome
        }
    }
}

extension View {
    /// Foundation chrome / tiles — resolves `Glass` from the active `GlassMode`.
    func foundationGlass<S: Shape>(interactive: Bool = false, in shape: S) -> some View {
        modifier(FoundationGlassModifier(interactive: interactive, shape: shape))
    }

    /// Semantic ink from the active glass palette.
    func glassInk(_ level: GlassInkLevel = .primary) -> some View {
        modifier(GlassInkModifier(level: level))
    }
}

/// Nav / toolbar circle control — always uses `foundationGlass` + palette ink (Clear/Dark).
struct GlassChromeIconButton: View {
    var systemName: String
    var accessibilityLabel: String
    var ink: Color? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(GlassChromeInkModifier(ink: ink))
        .foundationGlass(interactive: true, in: Circle())
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Capsule text control for toolbar actions like Edit.
struct GlassChromeLabelButton: View {
    var title: String
    var accessibilityLabel: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .glassInk()
                .padding(.horizontal, 16)
                .frame(height: 48)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foundationGlass(interactive: true, in: Capsule())
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}

private struct GlassChromeInkModifier: ViewModifier {
    var ink: Color?
    @Environment(\.glassPalette) private var palette

    func body(content: Content) -> some View {
        content.foregroundStyle(ink ?? palette.chrome)
    }
}
