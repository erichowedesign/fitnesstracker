import SwiftUI

/// User-facing Liquid Glass appearance. Persisted; drives glass material + ink palette.
/// - Clear → true untinted clear everywhere (no densifying tray fills)
/// - Dark → dark-tinted clear
/// - Light → denser frosted light material (the milky tab-bar look Eric captured)
enum GlassMode: String, CaseIterable, Identifiable, Codable, Hashable {
    case dark
    case light
    case clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .clear: return "Clear"
        }
    }

    /// Maps to SwiftUI `Glass` (iOS 26/27 Liquid Glass).
    /// Public Glass: `regular` / `clear` + `tint` / `interactive`.
    @available(iOS 26, *)
    func glass(interactive: Bool) -> Glass {
        let base: Glass
        switch self {
        case .clear:
            base = .clear
        case .dark:
            // Dark-tinted clear — still see-through, denser than Clear.
            base = .clear.tint(Color.black.opacity(0.38))
        case .light:
            // Denser frosted light material (former Clear tab-bar mismatch look).
            base = .regular.tint(Color.white)
        }
        return interactive ? base.interactive() : base
    }

    /// Extra fill under glass. Clear stays empty; Light/Dark get soft density.
    var glassUnderlay: Color? {
        switch self {
        case .clear:
            return nil
        case .dark:
            return Color.black.opacity(0.12)
        case .light:
            return Color.white.opacity(0.28)
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
    /// Color scheme for Liquid Glass / system materials.
    var colorScheme: ColorScheme
    /// Veil over the wash (Light only — keeps dark ink readable).
    var washVeil: Color
    /// Soft tray fill under chrome glass (tab bar, etc.). Clear = none.
    var chromeTray: Color
    /// Selected tab / chrome pill fill.
    var chromePill: Color
    /// Unselected chrome glyphs use plusLighter in Dark.
    var chromePlusLighter: Bool

    init(mode: GlassMode) {
        self.mode = mode
        accent = Color(red: 0, green: 0.569, blue: 1)
        heart = .pink
        switch mode {
        case .clear:
            // True clear: dark scheme so Liquid Glass stays clear; no milky tray.
            primary = Color(red: 0.961, green: 0.961, blue: 0.961)
            secondary = Color.white.opacity(0.85)
            tertiary = Color.white.opacity(0.72)
            chrome = Color(red: 0.961, green: 0.961, blue: 0.961)
            dim = Color.white.opacity(0.12)
            colorScheme = .dark
            washVeil = .clear
            chromeTray = .clear
            chromePill = Color.white.opacity(0.14)
            chromePlusLighter = true
        case .dark:
            primary = Color(red: 0.961, green: 0.961, blue: 0.961)
            secondary = Color.white.opacity(0.85)
            tertiary = Color.white.opacity(0.72)
            chrome = Color(red: 0.961, green: 0.961, blue: 0.961)
            dim = Color.white.opacity(0.12)
            colorScheme = .dark
            washVeil = .clear
            chromeTray = Color.black.opacity(0.22)
            chromePill = Color.black.opacity(0.36)
            chromePlusLighter = true
        case .light:
            // Denser light material — matches the milky Clear tab-bar screenshot look.
            primary = Color(red: 0.078, green: 0.078, blue: 0.078)
            secondary = Color.black.opacity(0.72)
            tertiary = Color.black.opacity(0.55)
            chrome = Color(red: 0.078, green: 0.078, blue: 0.078)
            dim = Color.black.opacity(0.1)
            colorScheme = .light
            washVeil = Color.white.opacity(0.16)
            chromeTray = Color.white.opacity(0.18)
            chromePill = Color.white.opacity(0.5)
            chromePlusLighter = false
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
        if let raw = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let saved = GlassMode(rawValue: raw) {
            mode = saved
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
                    shape.fill(fallbackFill)
                }
        }
    }

    private var fallbackFill: AnyShapeStyle {
        switch glassMode {
        case .clear:
            return AnyShapeStyle(Color.white.opacity(0.08))
        case .dark:
            return AnyShapeStyle(Color.black.opacity(0.28))
        case .light:
            return AnyShapeStyle(Color.white.opacity(0.82))
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

/// Nav / toolbar circle control — always uses `foundationGlass` + palette ink.
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
