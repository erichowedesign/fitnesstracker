import SwiftUI

struct RootTabs: View {
    @Environment(WashTheme.self) private var wash

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack {
                    HomeView()
                }
            }
            Tab("History", systemImage: "arrow.triangle.2.circlepath") {
                NavigationStack {
                    PlaceholderScreen(title: "History")
                }
            }
            Tab("Library", systemImage: "book") {
                NavigationStack {
                    PlaceholderScreen(title: "Library")
                }
            }
        }
        .tint(.blue)
        .onAppear {
            wash.grade = .grayscale
        }
    }
}

private struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
    }
}
