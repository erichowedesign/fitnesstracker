import SwiftUI

/// One-shot: wipe local routine edits and reseed history so Home Up Next is Upper Pull (C / 3).
private enum FoundationShippingReset {
    static let key = "foundation.shippingReset.v20261113-upper-pull"

    static func applyIfNeeded(store: SessionStore, overrides: RoutineOverridesStore) {
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        overrides.clearAll()
        store.reseedDemoHistoryForNextUpUpperPull()
        UserDefaults.standard.set(true, forKey: key)
    }
}

@main
struct FoundationApp: App {
    @State private var store = SessionStore()
    @State private var routineOverrides = RoutineOverridesStore()
    @State private var favorites = FavoritesStore()
    @State private var glassModeStore = GlassModeStore()
    @State private var wash = WashTheme()

    var body: some Scene {
        WindowGroup {
            RootTabs()
                .environment(store)
                .environment(routineOverrides)
                .environment(favorites)
                .environment(glassModeStore)
                .environment(wash)
                .environment(\.glassMode, glassModeStore.mode)
                .environment(\.glassPalette, glassModeStore.palette)
                .preferredColorScheme(glassModeStore.palette.colorScheme)
                .background(Color.black)
                .onAppear {
                    FoundationShippingReset.applyIfNeeded(store: store, overrides: routineOverrides)
                }
        }
    }
}
