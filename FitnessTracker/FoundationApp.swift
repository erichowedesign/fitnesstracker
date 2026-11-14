import SwiftUI

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
                .background(glassModeStore.mode == .light ? Color(white: 0.92) : Color.black)
        }
    }
}
