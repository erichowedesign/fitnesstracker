import SwiftUI

enum RootChromeLayout {
    static let menuButtonSize: CGFloat = 48
    static let trailingClusterSpacing: CGFloat = 8
    /// Standard inline navigation-bar content height. The floating root menu is a
    /// 48pt circle; top inset is `(toolbarContentHeight - menuButtonSize) / 2` so it
    /// shares the same vertical center as toolbar chrome (heart, back, menuSlot).
    static let toolbarContentHeight: CGFloat = 44
    static let menuTopInset: CGFloat = (toolbarContentHeight - menuButtonSize) / 2

    /// Invisible stand-in for the global RootTabs `RootChromeMenu` so other trailing
    /// chrome sits to its left without overlapping.
    static var menuSlot: some View {
        Color.clear
            .frame(width: menuButtonSize, height: menuButtonSize)
            .accessibilityHidden(true)
    }
}

/// Screen-scoped actions for the shared ellipsis menu (e.g. Edit routine on RoutineView).
@Observable
final class RootChromeActions {
    var editRoutine: (() -> Void)?
    /// When set, the top-trailing chrome shows a checkmark instead of the ellipsis menu.
    var doneEditing: (() -> Void)?
    var doneEditingEnabled: Bool = true

    func clearEditRoutine() {
        editRoutine = nil
    }

    func clearDoneEditing() {
        doneEditing = nil
        doneEditingEnabled = true
    }
}

/// Top-trailing more control: glass ellipsis → Theme / Pause–Play video → Clear / Dark / Light.
/// Idle trigger matches `GlassChromeIconButton` / `foundationGlass`; open levels use `GlassActionMenu`
/// (vertical float, page scrim, tap-outside dismiss).
struct RootChromeMenu: View {
    private enum Level {
        case idle
        case root
        case theme
    }

    @Environment(GlassModeStore.self) private var glassModeStore
    @Environment(WashTheme.self) private var wash
    @Environment(RootChromeActions.self) private var chromeActions
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

    private var videoMenuSymbol: String {
        wash.isVideoPlaying ? "pause.fill" : "play.fill"
    }

    private var videoMenuLabel: String {
        wash.isVideoPlaying ? "Pause video" : "Play video"
    }

    private var rootMenuItems: [GlassActionMenu.Item] {
        var items: [GlassActionMenu.Item] = [
            .init(symbol: "circle.lefthalf.filled", label: "Theme") {
                pendingTheme = true
            },
            .init(symbol: videoMenuSymbol, label: videoMenuLabel) {
                wash.toggleVideoPlayback()
            },
        ]
        if let editRoutine = chromeActions.editRoutine {
            items.append(
                .init(symbol: "pencil", label: "Edit routine", action: editRoutine)
            )
        }
        return items
    }

    private var showsDoneEditing: Bool {
        chromeActions.doneEditing != nil
    }

    var body: some View {
        ZStack {
            if let doneEditing = chromeActions.doneEditing {
                GlassChromeIconButton(
                    systemName: "checkmark",
                    accessibilityLabel: "Save edits",
                    action: doneEditing
                )
                .opacity(chromeActions.doneEditingEnabled ? 1 : 0.45)
                .allowsHitTesting(chromeActions.doneEditingEnabled)
            } else {
                switch level {
                case .idle:
                    GlassChromeIconButton(
                        systemName: "ellipsis",
                        accessibilityLabel: "More",
                        action: openRootMenu
                    )
                case .root:
                    GlassActionMenu(
                        items: rootMenuItems,
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
        }
        .frame(width: 48, height: 48)
        .zIndex(80)
        .accessibilityElement(children: .contain)
        .onChange(of: showsDoneEditing) { _, showingDone in
            guard showingDone else { return }
            level = .idle
            rootExpanded = false
            themeExpanded = false
            pendingTheme = false
        }
    }

    private func openRootMenu() {
        pendingTheme = false
        level = .root
        rootExpanded = false
        DispatchQueue.main.async { rootExpanded = true }
    }
}
