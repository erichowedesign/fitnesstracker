import SwiftUI

/// Top-trailing more control: glass ellipsis → Theme → Clear / Dark / Light.
/// Idle trigger matches `GlassChromeIconButton` / `foundationGlass`; open levels use `GlassActionMenu`
/// (vertical float, page scrim, tap-outside dismiss).
struct RootChromeMenu: View {
    private enum Level {
        case idle
        case root
        case theme
    }

    @Environment(GlassModeStore.self) private var glassModeStore
    @Environment(\.glassPalette) private var palette

    @State private var level: Level = .idle
    @State private var rootExpanded = false
    @State private var themeExpanded = false
    /// Theme was chosen; after the root menu finishes collapsing, open the theme menu.
    @State private var pendingTheme = false

    private var menuStyle: GlassActionMenu.Style {
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

    private var themeTriggerSymbol: String {
        switch glassModeStore.mode {
        case .dark: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .clear: return "circle"
        }
    }

    var body: some View {
        ZStack {
            switch level {
            case .idle:
                GlassChromeIconButton(
                    systemName: "ellipsis",
                    accessibilityLabel: "More",
                    action: openRootMenu
                )
            case .root:
                GlassActionMenu(
                    items: [
                        .init(symbol: "circle.lefthalf.filled", label: "Theme") {
                            pendingTheme = true
                        },
                    ],
                    triggerSymbol: "ellipsis",
                    arrangement: .linearDownwardFromTrailing,
                    isExpanded: $rootExpanded,
                    style: menuStyle
                )
                .onChange(of: rootExpanded) { _, open in
                    guard !open, level == .root else { return }
                    if pendingTheme {
                        pendingTheme = false
                        level = .theme
                        themeExpanded = false
                        DispatchQueue.main.async { themeExpanded = true }
                    } else {
                        level = .idle
                        pendingTheme = false
                    }
                }
            case .theme:
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
                    triggerSymbol: themeTriggerSymbol,
                    arrangement: .linearDownwardFromTrailing,
                    isExpanded: $themeExpanded,
                    style: menuStyle
                )
                .onChange(of: themeExpanded) { _, open in
                    guard !open, level == .theme else { return }
                    level = .idle
                }
            }
        }
        .frame(width: 48, height: 48)
        .zIndex(80)
        .accessibilityElement(children: .contain)
    }

    private func openRootMenu() {
        pendingTheme = false
        level = .root
        rootExpanded = false
        DispatchQueue.main.async { rootExpanded = true }
    }
}
