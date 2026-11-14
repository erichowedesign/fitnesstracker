import SwiftUI

/// Top-trailing ellipsis menu. Sectioned shell for future preferences (glass lives on the leading control).
struct RootMoreMenu: View {
    var body: some View {
        Menu {
            // Future sections land here.
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More")
    }
}

/// Top-leading glass mode control — SwiftPieces `GlassActionMenu` with Dark / Light / Clear.
struct GlassModeActionMenu: View {
    @Environment(GlassModeStore.self) private var glassModeStore

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
            ink: .white,
            labelInk: .white,
            triggerSize: 48,
            itemSize: 48,
            scrimOpacity: 0.32,
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
