import SwiftUI

private enum AppTab: Hashable {
    case home, history, library

    var order: Int {
        switch self {
        case .home: return 0
        case .history: return 1
        case .library: return 2
        }
    }
}

struct RootTabs: View {
    @Environment(WashTheme.self) private var wash
    @State private var tab: AppTab = .home
    @State private var previousTab: AppTab = .home
    @State private var hidesFloatingTabBar = false

    private var pageSlide: Animation { .smooth(duration: 0.35) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack {
                    tabPage(.home, width: width, height: proxy.size.height) {
                        HomeView(hidesFloatingTabBar: $hidesFloatingTabBar)
                    }
                    tabPage(.history, width: width, height: proxy.size.height) {
                        NavigationStack {
                            PlaceholderScreen(title: "History")
                        }
                    }
                    tabPage(.library, width: width, height: proxy.size.height) {
                        LibraryView(hidesFloatingTabBar: $hidesFloatingTabBar)
                    }
                }
                .frame(width: width, height: proxy.size.height, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

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

    private func tabPage<Content: View>(
        _ page: AppTab,
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let delta = page.order - tab.order
        let sliding = page == tab || page == previousTab
        return content()
            .frame(width: width, height: height)
            .offset(x: delta == 0 ? 0 : (delta > 0 ? width : -width))
            .transaction { transaction in
                if !sliding {
                    transaction.disablesAnimations = true
                }
            }
            .allowsHitTesting(page == tab)
            .accessibilityHidden(page != tab)
    }

    private func select(_ newTab: AppTab) {
        guard newTab != tab else { return }
        withAnimation(pageSlide) {
            previousTab = tab
            tab = newTab
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
                    tabButton(.home, title: "Home", systemImage: "house")
                    tabButton(.history, title: "History", systemImage: "clock.arrow.circlepath")
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
            select(value)
        } label: {
            VStack(spacing: 1) {
                Image(systemName: selected ? systemImage : (unselectedImage ?? systemImage))
                    .symbolVariant(.none)
                    .environment(\.symbolVariants, .none)
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
