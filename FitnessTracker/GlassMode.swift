import SwiftUI

/// User-facing Liquid Glass appearance. Persisted; applied to every Foundation glass surface.
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

    /// Maps to SwiftUI `Glass` (iOS 26 Liquid Glass).
    /// - Dark → `Glass.regular` (denser material)
    /// - Light → `Glass.regular.tint(.white)` (light-tinted regular)
    /// - Clear → `Glass.clear` (most translucent)
    @available(iOS 26, *)
    func glass(interactive: Bool) -> Glass {
        let base: Glass
        switch self {
        case .dark:
            base = .regular
        case .light:
            base = .regular.tint(.white)
        case .clear:
            base = .clear
        }
        return interactive ? base.interactive() : base
    }
}

@Observable
final class GlassModeStore {
    private static let defaultsKey = "foundation.glassMode"

    var mode: GlassMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.defaultsKey) }
    }

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

extension EnvironmentValues {
    var glassMode: GlassMode {
        get { self[GlassModeEnvironmentKey.self] }
        set { self[GlassModeEnvironmentKey.self] = newValue }
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
            content.glassEffect(glassMode.glass(interactive: interactive), in: shape)
        } else {
            content
                .background {
                    shape.fill(.ultraThinMaterial)
                }
        }
    }
}

extension View {
    /// Foundation chrome / tiles — resolves `Glass` from the active `GlassMode`.
    func foundationGlass<S: Shape>(interactive: Bool = false, in shape: S) -> some View {
        modifier(FoundationGlassModifier(interactive: interactive, shape: shape))
    }
}
