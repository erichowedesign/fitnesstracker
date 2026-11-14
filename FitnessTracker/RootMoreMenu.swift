import SwiftUI

/// Top-trailing ellipsis menu. Sectioned shell for future preferences (glass lives on the leading control).
struct RootMoreMenu: View {
    @Environment(\.glassPalette) private var palette

    var body: some View {
        Menu {
            // Future sections land here.
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.chrome)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foundationGlass(interactive: true, in: Circle())
        .accessibilityLabel("More")
    }
}

/// Top-leading glass mode control — Clear / Dark / Light.
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
        // Tighter itemSpacing than PieceLiquid.apart so Dark/Light/Clear stack snug when open.
        GlassActionMenu.Style(
            trigger: .clear,
            ink: palette.chrome,
            labelInk: palette.primary,
            triggerSize: 52,
            itemSize: 52,
            itemSpacing: 10,
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
            // Top-leading: stack options straight down the page.
            arrangement: .linearDownward,
            tint: nil,
            style: menuStyle
        )
        // No shadow/compositingGroup on this wrapper — they flatten and clip the piece’s page scrim.
        .zIndex(80)
        .accessibilityLabel("Glass mode")
    }
}
