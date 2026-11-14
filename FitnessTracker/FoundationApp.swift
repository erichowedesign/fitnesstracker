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
                // Inject stores first so chrome / pieces can resolve them.
                .environment(store)
                .environment(routineOverrides)
                .environment(favorites)
                .environment(glassModeStore)
                .environment(wash)
                // Mirror mode into the glassMode key (tracks Observable updates).
                .environment(\.glassMode, glassModeStore.mode)
                .background(Color.black)
                .preferredColorScheme(.dark)
        }
    }
}
