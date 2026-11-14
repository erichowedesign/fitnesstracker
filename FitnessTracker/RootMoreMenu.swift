import SwiftUI

/// Top-trailing glass mode control — Clear / Dark / Light.
/// Icons sit on the content trailing edge; open labels bud inward (leading of each icon).
struct GlassModeActionMenu: View {
    @Environment(GlassModeStore.self) private var glassModeStore
    @Environment(\.glassPalette) private var palette

    private var triggerSymbol: String {
        switch glassModeStore.mode {
        case .dark: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .clear: return "circle"
        }
    }

    private var menuStyle: GlassActionMenu.Style {
        // Piece default scrim (0.28) — do not zero/customize; outer shadows clip the full-page scrim.
        // itemSpacing inside PieceLiquid.merge (20) / near joined (4) so open items share liquid necks.
        GlassActionMenu.Style(
            trigger: .clear,
            ink: palette.chrome,
            labelInk: palette.primary,
            triggerSize: 48,
            itemSize: 48,
            itemSpacing: 4,
            confirmsAction: true
        )
    }

    var body: some View {
        GlassActionMenu(
            items: [
                .init(symbol: "circle.lefthalf.filled", label: "Dark") {
                    glassModeStore.mode = .dark
                },
                .init(symbol: "sun.max.fill", label: "Light") {
                    glassModeStore.mode = .light
                },
                .init(symbol: "circle", label: "Clear") {
                    glassModeStore.mode = .clear
                },
            ],
            triggerSymbol: triggerSymbol,
            // Top-trailing: stack down; names sit leading so icons stay on the content trailing edge.
            arrangement: .linearDownwardFromTrailing,
            tint: nil,
            style: menuStyle
        )
        // No shadow/compositingGroup on this wrapper — they flatten and clip the piece’s page scrim.
        .zIndex(80)
        .accessibilityLabel("Glass mode")
    }
}
