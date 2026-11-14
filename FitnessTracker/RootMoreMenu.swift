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

/// Top-leading glass mode control — SwiftPieces `GlassActionMenu` with Dark / Light / Clear.
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
        GlassActionMenu.Style(
            trigger: .clear,
            ink: palette.chrome,
            labelInk: palette.primary,
            triggerSize: 48,
            itemSize: 48,
            scrimOpacity: glassModeStore.mode == .light ? 0.18 : 0.32,
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
            arrangement: .arcDownTrailing,
            tint: nil,
            style: menuStyle
        )
        .accessibilityLabel("Glass mode")
    }
}
