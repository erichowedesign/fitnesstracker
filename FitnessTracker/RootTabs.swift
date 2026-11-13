import SwiftUI
import UIKit

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

struct RootTabs: View {
    @Environment(WashTheme.self) private var wash
    @State private var tab: AppTab = .home
    @State private var previousTab: AppTab = .home
    @State private var hidesFloatingTabBar = false
    @State private var dragOffset: CGFloat = 0
    @State private var isTracking = false
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

            tabHeader

            tabBar
                .opacity(hidesFloatingTabBar ? 0 : 1)
                .allowsHitTesting(!hidesFloatingTabBar)
                .accessibilityHidden(hidesFloatingTabBar)
                .animation(HomeHeroMotion.animation, value: hidesFloatingTabBar)
        }
        .preferredColorScheme(.dark)
        .background {
            TabPanBridge(isEnabled: !hidesFloatingTabBar, onChanged: applyDrag, onEnded: endDrag)
        }
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

    private func applyDrag(_ translation: CGFloat) {
        guard !hidesFloatingTabBar else { return }
        let width = max(pageWidth, 1)
        let lower: CGFloat = tab.previous == nil ? 0 : -width
        let upper: CGFloat = tab.next == nil ? 0 : width
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isTracking = true
            dragOffset = min(max(translation, lower), upper)
        }
    }

    private func endDrag(translation: CGFloat, predicted: CGFloat, cancelled: Bool) {
        isTracking = false
        guard !cancelled, !hidesFloatingTabBar else {
            settle(to: 0, selecting: nil)
            return
        }
        let width = max(pageWidth, 1)
        let travel = dragOffset
        let commitDistance = width * 0.22
        if (travel < -commitDistance || (predicted < -280 && travel < -12)), let next = tab.next {
            settle(to: -width, selecting: next)
        } else if (travel > commitDistance || (predicted > 280 && travel > 12)), let previous = tab.previous {
            settle(to: width, selecting: previous)
        } else {
            settle(to: 0, selecting: nil)
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
                .background { LockRootPopGesture(passThrough: true) }
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

/// Horizontal pans on the tab pages. A SwiftUI drag never begins here: the scroll
/// view and the navigation back pan take the touch first.
private struct TabPanBridge: UIViewRepresentable {
    var isEnabled: Bool
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ predicted: CGFloat, _ cancelled: Bool) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.install(from: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled = false
        var onChanged: (CGFloat) -> Void = { _ in }
        var onEnded: (CGFloat, CGFloat, Bool) -> Void = { _, _, _ in }
        let pan = UIPanGestureRecognizer()
        private weak var host: UIView?

        override init() {
            super.init()
            pan.addTarget(self, action: #selector(handlePan))
            pan.delegate = self
            pan.cancelsTouchesInView = false
        }

        func install(from anchor: UIView) {
            let host = ancestorHost(from: anchor)
            guard let host else {
                DispatchQueue.main.async { [weak self, weak anchor] in
                    guard let self, let anchor else { return }
                    self.install(from: anchor)
                }
                return
            }
            if pan.view !== host {
                pan.view?.removeGestureRecognizer(pan)
                host.addGestureRecognizer(pan)
                self.host = host
            }
            guard isEnabled else { return }
            linkScrollViews(in: host)
        }

        private func ancestorHost(from anchor: UIView) -> UIView? {
            let window = anchor.window ?? anchor.superview?.window
            guard let window else { return nil }
            var host: UIView = anchor
            while let parent = host.superview, parent !== window {
                host = parent
            }
            return host
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled, let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            let translation = pan.translation(in: pan.view)
            let dx = abs(velocity.x) > 1 ? abs(velocity.x) : abs(translation.x)
            let dy = abs(velocity.y) > 1 ? abs(velocity.y) : abs(translation.y)
            guard dx > 8 || dy > 8 else { return false }
            return dx > dy
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            isEnabled && otherGestureRecognizer.view is UIScrollView
        }

        @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
            let translation = pan.translation(in: pan.view).x
            switch pan.state {
            case .changed:
                onChanged(translation)
            case .ended:
                let velocity = pan.velocity(in: pan.view).x
                onEnded(translation, translation + velocity * 0.25, false)
            case .cancelled, .failed:
                onEnded(translation, translation, true)
            default:
                break
            }
        }

        private func linkScrollViews(in view: UIView) {
            if let scroll = view as? UIScrollView {
                scroll.panGestureRecognizer.require(toFail: pan)
            }
            for child in view.subviews {
                linkScrollViews(in: child)
            }
        }
    }
}

/// Root tab screens must not start a back transition. That gesture was hiding the bar.
struct LockRootPopGesture: UIViewControllerRepresentable {
    var passThrough = false

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.passThrough = passThrough
        return controller
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.passThrough = passThrough
        controller.apply()
    }

    final class Controller: UIViewController {
        var passThrough = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply()
        }

        func apply() {
            guard let nav = navigationController else { return }
            if passThrough {
                nav.view.isUserInteractionEnabled = false
                nav.interactivePopGestureRecognizer?.isEnabled = false
                nav.interactiveContentPopGestureRecognizer?.isEnabled = false
                return
            }
            guard nav.viewControllers.count <= 1 else { return }
            nav.interactivePopGestureRecognizer?.isEnabled = false
            nav.interactiveContentPopGestureRecognizer?.isEnabled = false
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
            .background { LockRootPopGesture() }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .opacity(0)
                        .accessibilityHidden(true)
                }
            }
    }
}
