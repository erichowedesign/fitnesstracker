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
        .toolbarBackground(.visible, for: .tabBar)
        .background(ClearTabChrome())
        .onAppear {
            wash.grade = .grayscale
        }
    }
}

private struct ClearTabChrome: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            var node: UIView? = uiView.superview
            while let view = node, !(view is UIWindow) {
                view.backgroundColor = .clear
                node = view.superview
            }
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
            .containerBackground(.clear, for: .navigation)
            .toolbarBackground(.hidden, for: .navigationBar)
            .background { Color.black.ignoresSafeArea() }
    }
}
