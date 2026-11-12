import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var store
    @Environment(WashTheme.self) private var wash
    @Namespace private var hero
    @State private var openedRoutineID: String?
    private let routines = WorkoutPlan.all()

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

                NavigationLink(value: upNext) {
                    UpNextCard(
                        routine: upNext,
                        hero: hero,
                        isHeroSource: openedRoutineID != upNext.id
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
                        NavigationLink(value: routine) {
                            RoutineListCard(
                                routine: routine,
                                hero: hero,
                                isHeroSource: openedRoutineID != routine.id
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
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color.black
                WashBackground(grade: wash.grade)
            }
            .ignoresSafeArea()
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Foundation")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
            }
        }
        .navigationDestination(for: Routine.self) { routine in
            RoutineView(routine: routine, hero: hero)
                .homeHeroZoom(id: routine.id, in: hero)
                .onAppear { openedRoutineID = routine.id }
                .onDisappear {
                    if openedRoutineID == routine.id {
                        openedRoutineID = nil
                    }
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
}

/// Apple concentric corners: innerRadius = tile 34 − gap to the illustration square.
private func homeIllustrationThumb(gap: CGFloat) -> RoundedRectangle {
    RoundedRectangle(cornerRadius: 34 - gap, style: .continuous)
}

private struct UpNextCard: View {
    let routine: Routine
    var hero: Namespace.ID
    var isHeroSource: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack {
                WashWindow(grade: WashGrade.forRoutine(routine.id))
                    .clipShape(homeIllustrationThumb(gap: 20))
                    .matchedTransitionSource(id: routine.id, in: hero)
                IllustrationView(slug: routine.heroSlug, label: routine.name)
                    .frame(width: 210, height: 210)
            }
            .frame(width: 210, height: 210)
            .clipShape(homeIllustrationThumb(gap: 20))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 28)
            .padding(.trailing, 20)

            Text("Routine \(routine.rotationIndex)")
                .font(.subheadline)
                .homeHeroMatch("eyebrow-\(routine.id)", in: hero, isSource: isHeroSource)
                .padding(.top, 22)
                .padding(.leading, 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .homeHeroMatch("title-\(routine.id)", in: hero, isSource: isHeroSource)
                Text(routine.focus)
                    .font(.body)
                    .homeHeroMatch("focus-\(routine.id)", in: hero, isSource: isHeroSource)
                HStack(spacing: 8) {
                    Text("\(routine.workoutsLine) /")
                        .font(.subheadline)
                    DifficultyBars(filled: routine.difficulty)
                        .scaleEffect(0.55, anchor: .leading)
                        .frame(width: 48, height: 18)
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 370)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(routine.name), \(routine.focus), \(routine.workoutsLine)")
    }
}

private struct RoutineListCard: View {
    let routine: Routine
    var hero: Namespace.ID
    var isHeroSource: Bool

    private var poseSlug: String {
        switch routine.id {
        case "B": return "leg-extension"
        case "C": return "seated-row"
        case "D": return "step-up"
        default: return routine.exercises.first?.slug ?? routine.heroSlug
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 20) {
                ZStack {
                    WashWindow(grade: WashGrade.forRoutine(routine.id))
                        .clipShape(homeIllustrationThumb(gap: 16))
                        .matchedTransitionSource(id: routine.id, in: hero)
                    IllustrationView(slug: poseSlug, label: routine.name)
                        .frame(width: 120, height: 120)
                }
                .frame(width: 120, height: 120)
                .clipShape(homeIllustrationThumb(gap: 16))
                .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 23) {
                    Text("Routine \(routine.rotationIndex)")
                        .font(.system(size: 15))
                        .frame(height: 18, alignment: .leading)
                        .homeHeroMatch("eyebrow-\(routine.id)", in: hero, isSource: isHeroSource)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(routine.name)
                            .font(.system(size: 22, weight: .semibold))
                            .frame(height: 25, alignment: .leading)
                            .lineLimit(1)
                            .homeHeroMatch("title-\(routine.id)", in: hero, isSource: isHeroSource)
                        Text(routine.focus)
                            .font(.system(size: 16))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .homeHeroMatch("focus-\(routine.id)", in: hero, isSource: isHeroSource)
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
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Routine \(routine.rotationIndex), \(routine.name), \(routine.focus)")
    }
}

extension View {
    func homeHeroMatch(_ id: String, in ns: Namespace.ID?, isSource: Bool = true) -> some View {
        modifier(HomeHeroMatchModifier(id: id, namespace: ns, isSource: isSource))
    }

    func homeHeroZoom(id: String, in ns: Namespace.ID?) -> some View {
        modifier(HomeHeroZoomModifier(id: id, namespace: ns))
    }
}

private struct HomeHeroMatchModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID?
    let isSource: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if let namespace, !reduceMotion {
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
    NavigationStack {
        HomeView()
    }
    .environment(SessionStore())
    .environment(WashTheme())
    .preferredColorScheme(.dark)
}
