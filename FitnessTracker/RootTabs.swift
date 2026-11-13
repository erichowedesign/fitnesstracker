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

    var next: AppTab? {
        switch self {
        case .home: return .history
        case .history: return .library
        case .library: return nil
        }
    }

    var previous: AppTab? {
        switch self {
        case .home: return nil
        case .history: return .home
        case .library: return .history
        }
    }
}

private enum TabDragAxis {
    case horizontal, vertical
}

struct RootTabs: View {
    @Environment(WashTheme.self) private var wash
    @State private var tab: AppTab = .home
    @State private var previousTab: AppTab = .home
    @State private var hidesFloatingTabBar = false
    @State private var dragOffset: CGFloat = 0
    @State private var isTracking = false
    @State private var dragAxis: TabDragAxis?
    @State private var pageWidth: CGFloat = 1
    @State private var settleID = UUID()

    private var pageSlide: Animation { .smooth(duration: 0.35) }

    /// The neighbor currently peeking in. One swipe only moves one tab.
    private var dragNeighbor: AppTab? {
        if dragOffset < -0.5 { return tab.next }
        if dragOffset > 0.5 { return tab.previous }
        return nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            WashBackground(grade: wash.grade)

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
                .clipped()
                .onAppear { pageWidth = width }
                .onChange(of: width) { _, newValue in
                    pageWidth = newValue
                }
            }
            .ignoresSafeArea()
            .modifier(TabSwipeAttachment(isEnabled: !hidesFloatingTabBar, gesture: tabDrag))

            tabHeader

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
        let sliding = page == tab || page == previousTab || page == dragNeighbor
        let base: CGFloat = delta == 0 ? 0 : (delta > 0 ? width : -width)
        return content()
            .frame(width: width, height: height)
            .offset(x: base + dragOffset)
            .transaction { transaction in
                if isTracking || !sliding {
                    transaction.disablesAnimations = true
                }
            }
            .allowsHitTesting(page == tab)
            .accessibilityHidden(page != tab)
    }

    private func select(_ newTab: AppTab) {
        guard newTab != tab else { return }
        settleID = UUID()
        isTracking = false
        withAnimation(pageSlide) {
            dragOffset = 0
            previousTab = tab
            tab = newTab
        }
    }

    private var tabDrag: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                guard !hidesFloatingTabBar else { return }
                let translation = value.translation
                if dragAxis == nil {
                    guard hypot(translation.width, translation.height) > 12 else { return }
                    dragAxis = abs(translation.width) > abs(translation.height) * 1.2 ? .horizontal : .vertical
                }
                guard dragAxis == .horizontal else { return }
                let width = max(pageWidth, 1)
                let lower: CGFloat = tab.previous == nil ? 0 : -width
                let upper: CGFloat = tab.next == nil ? 0 : width
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isTracking = true
                    dragOffset = min(max(translation.width, lower), upper)
                }
            }
            .onEnded { value in
                let axis = dragAxis
                dragAxis = nil
                isTracking = false
                guard axis == .horizontal, !hidesFloatingTabBar else {
                    if dragOffset != 0 { settle(to: 0, selecting: nil) }
                    return
                }
                let width = max(pageWidth, 1)
                let travel = dragOffset
                let predicted = value.predictedEndTranslation.width
                let commitDistance = width * 0.22
                if (travel < -commitDistance || (predicted < -280 && travel < -12)), let next = tab.next {
                    settle(to: -width, selecting: next)
                } else if (travel > commitDistance || (predicted > 280 && travel > 12)), let previous = tab.previous {
                    settle(to: width, selecting: previous)
                } else {
                    settle(to: 0, selecting: nil)
                }
            }
    }

    /// Finishes the slide, then swaps the selected tab without a second jump.
    private func settle(to target: CGFloat, selecting next: AppTab?) {
        let id = UUID()
        settleID = id
        isTracking = false
        withAnimation(pageSlide, completionCriteria: .logicallyComplete) {
            dragOffset = target
        } completion: {
            guard settleID == id else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if let next {
                    previousTab = tab
                    tab = next
                }
                dragOffset = 0
            }
        }
    }

    /// Title and menu stay fixed while the pages slide. Only the title fades.
    private var tabHeader: some View {
        NavigationStack {
            Color.clear
                .containerBackground(.clear, for: .navigation)
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                .toolbarTitleDisplayMode(.inline)
                .scrollEdgeEffectHidden(true, for: .vertical)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        ZStack {
                            tabTitle("Foundation", page: .home)
                            tabTitle("History", page: .history)
                            tabTitle("Library", page: .library)
                        }
                    }
                    ToolbarItem(id: "tab-menu", placement: .topBarTrailing) {
                        Button {
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                        .accessibilityLabel("More")
                    }
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .opacity(hidesFloatingTabBar ? 0 : 1)
        .animation(HomeHeroMotion.animation, value: hidesFloatingTabBar)
        .accessibilityHidden(hidesFloatingTabBar)
    }

    private func tabTitle(_ title: String, page: AppTab) -> some View {
        let opacity = titleOpacity(for: page)
        return Text(title)
            .font(.headline)
            .fontWeight(.semibold)
            .opacity(opacity)
            .accessibilityHidden(opacity < 0.5)
    }

    private func titleOpacity(for page: AppTab) -> Double {
        guard pageWidth > 1 else { return page == tab ? 1 : 0 }
        let progress = min(max(dragOffset / pageWidth, -1), 1)
        if page == tab {
            return 1 - abs(progress)
        }
        if progress < 0, page == tab.next {
            return -progress
        }
        if progress > 0, page == tab.previous {
            return progress
        }
        return 0
    }

    private var selectedPillX: CGFloat {
        let base: CGFloat
        switch tab {
        case .home: base = 0
        case .history: base = 94
        case .library: base = 188
        }
        guard pageWidth > 1 else { return base }
        let progress = min(max(dragOffset / pageWidth, -1), 1)
        return min(max(base - progress * 94, 0), 188)
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

private struct TabSwipeAttachment<G: Gesture>: ViewModifier {
    var isEnabled: Bool
    var gesture: G

    func body(content: Content) -> some View {
        if isEnabled {
            content.simultaneousGesture(gesture)
        } else {
            content
        }
    }
}

private struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title2)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(.clear, for: .navigation)
            .scrollEdgeEffectHidden(true, for: .vertical)
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .opacity(0)
                        .accessibilityHidden(true)
                }
            }
    }
}
