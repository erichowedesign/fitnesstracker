import SwiftUI

@main
struct FoundationApp: App {
    @State private var store = SessionStore()
    @State private var routineOverrides = RoutineOverridesStore()
    @State private var favorites = FavoritesStore()
    @State private var wash = WashTheme()

    var body: some Scene {
        WindowGroup {
            RootTabs()
                .environment(store)
                .environment(routineOverrides)
                .environment(favorites)
                .environment(wash)
                .background(Color.black)
                .preferredColorScheme(.dark)
        }
    }
}
