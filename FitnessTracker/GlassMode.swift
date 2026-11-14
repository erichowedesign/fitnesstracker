import SwiftUI

/// User-facing Liquid Glass appearance. Persisted; drives glass material + ink palette.
/// Clear = fully clear glass. Dark = regular / dark material (clearly denser than Clear).
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
    /// - Clear → fully clear
    /// - Dark → regular glass with black tint + underlay (not almost-clear)
    @available(iOS 26, *)
    func glass(interactive: Bool) -> Glass {
        let base: Glass
        switch self {
        case .dark:
            // Regular liquid glass tinted dark so it reads clearly denser than Clear.
            base = .regular.tint(Color.black.opacity(0.78))
        case .clear:
            base = .clear
        }
        return interactive ? base.interactive() : base
    }

    /// Extra fill under glass — Dark only, so Clear stays transparent.
    var glassUnderlay: Color? {
        switch self {
        case .dark:
            return Color.black.opacity(0.32)
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
    /// Color scheme for system materials / ScrubStepper adaptive bits.
    var colorScheme: ColorScheme
    /// Veil over the wash (unused for Clear/Dark; both keep wash visible).
    var washVeil: Color

    init(mode: GlassMode) {
        self.mode = mode
        accent = Color(red: 0, green: 0.569, blue: 1)
        heart = .pink
        // Clear + Dark both sit on the wash with light ink.
        primary = Color(red: 0.961, green: 0.961, blue: 0.961)
        secondary = Color.white.opacity(0.85)
        tertiary = Color.white.opacity(0.72)
        chrome = Color(red: 0.961, green: 0.961, blue: 0.961)
        dim = Color.white.opacity(0.12)
        colorScheme = .dark
        washVeil = .clear
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
                            ? AnyShapeStyle(Color.black.opacity(0.72))
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
