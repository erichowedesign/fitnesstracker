import SwiftUI

@main
struct FoundationApp: App {
    @State private var store = SessionStore()
    @State private var wash = WashTheme()

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()
                WashBackground(grade: wash.grade)
                RootTabs()
            }
            .environment(store)
            .environment(wash)
            .preferredColorScheme(.dark)
        }
    }
}
