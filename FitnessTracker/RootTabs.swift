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

    private var selectedPillX: CGFloat {
        switch tab {
        case .home: return 0
        case .history: return 94
        case .library: return 188
        }
    }

    private var tabBar: some View {
        ZStack {
            Capsule()
                .fill(Color.black.opacity(0.6))
            Capsule()
                .fill(Color.white.opacity(0.06))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255))
                    .blendMode(.plusLighter)
                    .frame(width: 106, height: 54)
                    .offset(x: selectedPillX)

                HStack(spacing: -8) {
                    tabButton(.home, title: "Home", systemImage: "house.fill", unselectedImage: "house")
                    tabButton(.history, title: "History", systemImage: "arrow.triangle.2.circlepath")
                    tabButton(.library, title: "Library", systemImage: "book")
                }
                .padding(.horizontal, 2)
            }
            .frame(width: 294, height: 54)
        }
        .frame(width: 302, height: 62)
        .glassEffect(.regular.interactive(), in: Capsule())
        .padding(.bottom, 8)
        .animation(.snappy(duration: 0.25), value: tab)
    }

    private func tabButton(
        _ value: AppTab,
        title: String,
        systemImage: String,
        unselectedImage: String? = nil
    ) -> some View {
        let selected = tab == value
        return Button {
            tab = value
        } label: {
            VStack(spacing: 1) {
                Image(systemName: selected ? systemImage : (unselectedImage ?? systemImage))
                    .font(.system(size: 20, weight: .medium))
                    .frame(height: 28)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .frame(height: 12)
            }
            .foregroundStyle(
                selected
                    ? Color(red: 0, green: 0.569, blue: 1)
                    : Color(red: 0.961, green: 0.961, blue: 0.961)
            )
            .blendMode(selected ? .normal : .plusLighter)
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .frame(width: 102, height: 54, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
