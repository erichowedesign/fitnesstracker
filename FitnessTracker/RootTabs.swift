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
    @Environment(\.glassPalette) private var palette
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
            palette.washVeil
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.smooth(duration: 0.35), value: palette.mode)

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack {
                    tabPage(.home, width: width, height: proxy.size.height) {
                        HomeView(hidesFloatingTabBar: $hidesFloatingTabBar)
                    }
                    tabPage(.history, width: width, height: proxy.size.height) {
                        HistoryView()
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

            chromeMenusOverlay

            tabBar
                .opacity(hidesFloatingTabBar ? 0 : 1)
                .allowsHitTesting(!hidesFloatingTabBar)
                .accessibilityHidden(hidesFloatingTabBar)
                .animation(.smooth(duration: 0.35), value: hidesFloatingTabBar)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(palette.primary)
        .preferredColorScheme(palette.colorScheme)
        .background {
            TabPanBridge(isEnabled: !hidesFloatingTabBar, onChanged: applyDrag, onEnded: endDrag)
        }
        .onAppear {
            wash.grade = .grayscale
        }
        .animation(.smooth(duration: 0.3), value: palette.mode)
    }

    /// Leading: glass mode action menu. Trailing: extensible more menu. Tab header stays pass-through.
    /// Avoid clip/compositing on this layer so GlassActionMenu’s full-page scrim can paint over the wash.
    private var chromeMenusOverlay: some View {
        VStack {
            HStack(alignment: .top) {
                GlassModeActionMenu()
                    .padding(.leading, 12)
                Spacer(minLength: 0)
                RootMoreMenu()
                    .padding(.trailing, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .opacity(hidesFloatingTabBar ? 0 : 1)
        .allowsHitTesting(!hidesFloatingTabBar)
        .accessibilityHidden(hidesFloatingTabBar)
        .animation(.smooth(duration: 0.35), value: hidesFloatingTabBar)
        // Above pages + wash so GlassActionMenu / more control stay a floating layer.
        .zIndex(100)
    }

    private func tabPage<Content: View>(
        _ page: AppTab,
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let delta = page.order - tab.order
        // Only the selected page and the one being revealed should paint. The old
        // ±width clamp stacked every page on the same side, so Library flashed
        // over History while settling Home → History.
        let sliding = page == tab || page == previousTab || page == dragNeighbor
        let base = CGFloat(delta) * width
        return content()
            .frame(width: width, height: height)
            .background(Color.clear)
            .offset(x: base + dragOffset)
            .opacity(sliding ? 1 : 0)
            .zIndex(page == tab ? 2 : (sliding ? 1 : 0))
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
        // Finger left (negative) reveals the next tab. Finger right reveals the previous one.
        let lower: CGFloat = tab.next == nil ? 0 : -width
        let upper: CGFloat = tab.previous == nil ? 0 : width
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
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .opacity(hidesFloatingTabBar ? 0 : 1)
        .animation(.smooth(duration: 0.35), value: hidesFloatingTabBar)
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

    /// Same Clear/Dark/Light glass as tiles via `foundationGlass`. Tray/pill fills come from the palette
    /// (Clear = no milky tray; Light keeps the denser frosted tray that mismatched Clear before).
    private var tabBar: some View {
        ZStack {
            // Clear: no tray fills — glass alone matches tiles. Light/Dark keep densifying trays.
            if palette.mode != .clear {
                Capsule()
                    .fill(palette.chromeTray)
                Capsule()
                    .fill(palette.dim.opacity(0.5))
            }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.chromePill)
                    .blendMode(palette.chromePlusLighter ? .plusLighter : .normal)
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
        .foundationGlass(interactive: true, in: Capsule())
        .padding(.bottom, 8)
        .animation(.snappy(duration: 0.25), value: tab)
        .animation(.smooth(duration: 0.3), value: palette.mode)
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
            .foregroundStyle(selected ? palette.accent : palette.chrome)
            .blendMode(selected || !palette.chromePlusLighter ? .normal : .plusLighter)
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

/// Horizontal pans on the tab pages. Tile presses wait for this pan so a sideways
/// drag is not treated as a hold.
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
            // A tile press must not see the touch until this pan fails. If the
            // pan begins, cancel that press so the drag is not a hold.
            pan.cancelsTouchesInView = true
            pan.delaysTouchesBegan = true
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
            linkGestures(in: host)
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
            let dx = max(abs(velocity.x), abs(translation.x))
            let dy = max(abs(velocity.y), abs(translation.y))
            guard dx > 1 || dy > 1 else { return false }
            return dx >= dy
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Tile presses and scroll pans wait. A horizontal drag wins; a tap
            // runs only after this pan fails.
            isEnabled && otherGestureRecognizer !== pan
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

        private func linkGestures(in view: UIView) {
            if let scroll = view as? UIScrollView {
                scroll.panGestureRecognizer.require(toFail: pan)
            }
            for recognizer in view.gestureRecognizers ?? [] where recognizer !== pan {
                if let scroll = view as? UIScrollView, recognizer === scroll.panGestureRecognizer {
                    continue
                }
                recognizer.require(toFail: pan)
            }
            for child in view.subviews {
                linkGestures(in: child)
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

