import SwiftUI

@main
struct FoundationApp: App {
    @State private var store = SessionStore()

    var body: some Scene {
        WindowGroup {
            UpperPushView()
                .environment(store)
        }
    }
}
