import SwiftUI

private enum AppTab: Hashable {
    case home, history, library
}

struct RootTabs: View {
    @Environment(WashTheme.self) private var wash
    @State private var tab: AppTab = .home
    @State private var hidesFloatingTabBar = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            Group {
                switch tab {
                case .home:
                    HomeView(hidesFloatingTabBar: $hidesFloatingTabBar)
                case .history:
                    NavigationStack {
                        PlaceholderScreen(title: "History")
                    }
                case .library:
                    NavigationStack {
                        PlaceholderScreen(title: "Library")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
                .opacity(hidesFloatingTabBar ? 0 : 1)
                .allowsHitTesting(!hidesFloatingTabBar)
                .accessibilityHidden(hidesFloatingTabBar)
                .animation(HomeHeroMotion.animation, value: hidesFloatingTabBar)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            wash.grade = .grayscale
        }
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            tabButton(.home, title: "Home", systemImage: "house.fill")
            tabButton(.history, title: "History", systemImage: "arrow.triangle.2.circlepath")
            tabButton(.library, title: "Library", systemImage: "book")
        }
        .padding(6)
        .glassEffect(.regular.interactive(), in: Capsule())
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private func tabButton(_ value: AppTab, title: String, systemImage: String) -> some View {
        Button {
            tab = value
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(tab == value ? Color.blue : Color.white.opacity(0.72))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if tab == value {
                        Capsule()
                            .fill(.white.opacity(0.16))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(tab == value ? .isSelected : [])
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
                ZStack {
                    Color.black
                    WashBackground(grade: wash.grade)
                }
                .ignoresSafeArea()
            }
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}
