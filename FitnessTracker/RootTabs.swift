import SwiftUI

struct RootTabs: View {
    @Environment(WashTheme.self) private var wash

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                PlaceholderScreen(title: "History")
            }
            .tabItem { Label("History", systemImage: "arrow.triangle.2.circlepath") }

            NavigationStack {
                PlaceholderScreen(title: "Library")
            }
            .tabItem { Label("Library", systemImage: "book") }
        }
        .tint(.blue)
        .preferredColorScheme(.dark)
        .onAppear {
            wash.grade = .grayscale
        }
    }
}

private struct PlaceholderScreen: View {
    @Environment(WashTheme.self) private var wash
    let title: String

    var body: some View {
        Text(title)
            .font(.title2)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                WashBackground(grade: wash.grade)
            }
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
    }
}
