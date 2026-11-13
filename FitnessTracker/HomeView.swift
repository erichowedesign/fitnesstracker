import SwiftUI

enum HomeHeroMotion {
    static let duration: TimeInterval = 0.8
    static var animation: Animation { .smooth(duration: duration) }
}

struct HomeView: View {
    @Environment(SessionStore.self) private var store
    @Environment(WashTheme.self) private var wash
    @Namespace private var hero
    @Binding var hidesFloatingTabBar: Bool
    @State private var path: [Routine] = []
    @State private var heroMatchEnabled = true
    private let routines = WorkoutPlan.all()

    init(hidesFloatingTabBar: Binding<Bool> = .constant(false)) {
        _hidesFloatingTabBar = hidesFloatingTabBar
    }

    private var upNext: Routine {
        store.nextRoutine(in: routines)
    }

    private var myRoutines: [Routine] {
        store.remainingRoutines(after: upNext, in: routines)
    }

    /// Lets the last tile scroll into the upper half, clear of the pinned tab bar.
    private var homeScrollBottomInset: CGFloat {
        max(WashPlayback.screenSize.height * 0.5, 400)
    }

    var body: some View {
        NavigationStack(path: $path) {
            homeScroll
        }
    }

    private var homeScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Get to Work")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("You got a lot of shit to get done")
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                Text("Up Next")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.top, 48)

                Button {
                    openRoutine(upNext)
                } label: {
                    UpNextCard(
                        routine: upNext,
                        hero: hero,
                        matchEnabled: heroMatchEnabled
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 24)

                Text("My Routines")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.top, 48)

                VStack(spacing: 12) {
                    ForEach(myRoutines) { routine in
                        Button {
                            openRoutine(routine)
                        } label: {
                            RoutineListCard(
                                routine: routine,
                                hero: hero,
                                matchEnabled: heroMatchEnabled
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .contentMargins(.bottom, homeScrollBottomInset, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectHidden(true, for: .vertical)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.clear, for: .navigation)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .navigationTitle("Foundation")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Foundation")
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }
        .navigationDestination(for: Routine.self) { routine in
            RoutineView(routine: routine, hero: hero, heroMatchEnabled: heroMatchEnabled)
                .homeHeroZoom(id: routine.id, in: hero)
        }
        .onChange(of: path) { _, newPath in
            hidesFloatingTabBar = !newPath.isEmpty
            if newPath.isEmpty {
                heroMatchEnabled = true
            }
        }
        .onAppear {
            wash.grade = .grayscale
        }
        .overlay(alignment: .top) {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.28), location: 0),
                    .init(color: .black.opacity(0.12), location: 0.45),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func openRoutine(_ routine: Routine) {
        heroMatchEnabled = true
        hidesFloatingTabBar = true
        withAnimation(HomeHeroMotion.animation) {
            path.append(routine)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(HomeHeroMotion.duration))
            guard path.last?.id == routine.id else { return }
            heroMatchEnabled = false
        }
    }
}

/// Apple concentric corners: innerRadius = tile 34 − gap to the illustration square.
private func homeIllustrationThumb(gap: CGFloat) -> RoundedRectangle {
    RoundedRectangle(cornerRadius: 34 - gap, style: .continuous)
}

private struct UpNextCard: View {
    let routine: Routine
    var hero: Namespace.ID
    var matchEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                WashWindow(grade: WashGrade.forRoutine(routine.id))
                IllustrationView(slug: routine.heroSlug, label: routine.name)
                    .frame(width: 192, height: 192)
                    .homeHeroMatch("hero-art-\(routine.id)", in: hero, isSource: true, enabled: matchEnabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .foregroundStyle(.white)
                Color.clear
                    .matchedTransitionSource(id: routine.id, in: hero)
                Text("Routine \(routine.rotationIndex)")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .homeHeroMatch("eyebrow-\(routine.id)", in: hero, isSource: true, enabled: matchEnabled)
                    .padding(.top, 16)
                    .padding(.leading, 32)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 216)
            .clipped()

            VStack(alignment: .leading, spacing: 0) {
                Text(routine.name)
                    .font(.system(size: 28, weight: .bold))
                    .frame(height: 34, alignment: .leading)
                    .homeHeroMatch("title-\(routine.id)", in: hero, isSource: true, enabled: matchEnabled)
                Text(routine.focus)
                    .font(.body)
                    .homeHeroMatch("focus-\(routine.id)", in: hero, isSource: true, enabled: matchEnabled)
                    .padding(.top, 4)
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 8) {
                    Text("\(routine.exerciseCountLabel) workouts / \(routine.minutes) minutes /")
                        .font(.subheadline)
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(.white)
                                .frame(width: 4, height: 14)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 358)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(routine.name), \(routine.focus), \(routine.workoutsLine)")
    }
}

private struct RoutineListCard: View {
    let routine: Routine
    var hero: Namespace.ID
    var matchEnabled: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 20) {
                ZStack {
                    WashWindow(grade: WashGrade.forRoutine(routine.id))
                        .clipShape(homeIllustrationThumb(gap: 16))
                    IllustrationView(slug: routine.heroSlug, label: routine.name)
                        .frame(width: 120, height: 120)
                        .homeHeroMatch("hero-art-\(routine.id)", in: hero, isSource: true, enabled: matchEnabled)
                    Color.clear
                        .matchedTransitionSource(id: routine.id, in: hero)
                }
                .frame(width: 120, height: 120)
                .clipShape(homeIllustrationThumb(gap: 16))
                .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 23) {
                    Text("Routine \(routine.rotationIndex)")
                        .font(.system(size: 15))
                        .frame(height: 18, alignment: .leading)
                        .homeHeroMatch("eyebrow-\(routine.id)", in: hero, isSource: true, enabled: matchEnabled)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(routine.name)
                            .font(.system(size: 22, weight: .semibold))
                            .frame(height: 25, alignment: .leading)
                            .lineLimit(1)
                            .homeHeroMatch("title-\(routine.id)", in: hero, isSource: true, enabled: matchEnabled)
                        Text(routine.focus)
                            .font(.system(size: 16))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .homeHeroMatch("focus-\(routine.id)", in: hero, isSource: true, enabled: matchEnabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.white)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 152)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Routine \(routine.rotationIndex), \(routine.name), \(routine.focus)")
    }
}

extension View {
    func homeHeroMatch(_ id: String, in ns: Namespace.ID?, isSource: Bool = true, enabled: Bool = true) -> some View {
        modifier(HomeHeroMatchModifier(id: id, namespace: ns, isSource: isSource, enabled: enabled))
    }

    func homeHeroZoom(id: String, in ns: Namespace.ID?) -> some View {
        modifier(HomeHeroZoomModifier(id: id, namespace: ns))
    }
}

private struct HomeHeroMatchModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID?
    let isSource: Bool
    var enabled: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if let namespace, enabled, !reduceMotion {
            content.matchedGeometryEffect(id: id, in: namespace, isSource: isSource)
        } else {
            content
        }
    }
}

private struct HomeHeroZoomModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if let namespace, !reduceMotion {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

#Preview {
    HomeView()
    .environment(SessionStore())
    .environment(WashTheme())
    .preferredColorScheme(.dark)
}
