import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var store
    @Environment(RoutineOverridesStore.self) private var routineOverrides
    @Environment(WashTheme.self) private var wash
    @Binding var hidesFloatingTabBar: Bool
    @State private var path: [Routine] = []
    @State private var showResetRoutinesConfirm = false

    init(hidesFloatingTabBar: Binding<Bool> = .constant(false)) {
        _hidesFloatingTabBar = hidesFloatingTabBar
    }

    private var routines: [Routine] {
        WorkoutPlan.all().map(routineOverrides.resolved)
    }

    private var upNext: Routine {
        store.nextRoutine(in: routines)
    }

    private var myRoutines: [Routine] {
        store.remainingRoutines(after: upNext, in: routines)
    }

    /// Clears the floating tab bar; matches History’s bottom scroll inset.
    private var homeScrollBottomInset: CGFloat { 120 }

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
                    UpNextCard(routine: upNext)
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
                            RoutineListCard(routine: routine)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 24)

                Button("Reset Routines") {
                    showResetRoutinesConfirm = true
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .accessibilityHint("Restores stock warm-ups, main workouts, and cool-downs")
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
        .background { LockRootPopGesture() }
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
            RoutineView(routine: routine)
        }
        .alert("Reset routines?", isPresented: $showResetRoutinesConfirm) {
            Button("Reset", role: .destructive) {
                routineOverrides.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Restores stock warm-ups, main workouts, and cool-downs for every routine on this iPhone. Workout history is kept.")
        }
        .onChange(of: path) { _, newPath in
            hidesFloatingTabBar = !newPath.isEmpty
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
        hidesFloatingTabBar = true
        path.append(routine)
    }
}

/// Apple concentric corners: innerRadius = tile 34 − gap to the illustration square.
private func homeIllustrationThumb(gap: CGFloat) -> RoundedRectangle {
    RoundedRectangle(cornerRadius: 34 - gap, style: .continuous)
}

private struct UpNextCard: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                WashWindow(grade: WashGrade.forRoutine(routine.id))
                IllustrationView(slug: routine.heroSlug, label: routine.name)
                    .frame(width: 192, height: 192)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .foregroundStyle(.white)
                Text("Routine \(routine.rotationIndex)")
                    .font(.subheadline)
                    .foregroundStyle(.white)
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
                Text(routine.focus)
                    .font(.body)
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
        .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(routine.name), \(routine.focus), \(routine.workoutsLine)")
    }
}

private struct RoutineListCard: View {
    let routine: Routine

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 20) {
                ZStack {
                    WashWindow(grade: WashGrade.forRoutine(routine.id))
                        .clipShape(homeIllustrationThumb(gap: 16))
                    IllustrationView(slug: routine.heroSlug, label: routine.name)
                        .frame(width: 120, height: 120)
                }
                .frame(width: 120, height: 120)
                .clipShape(homeIllustrationThumb(gap: 16))
                .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 23) {
                    Text("Routine \(routine.rotationIndex)")
                        .font(.system(size: 15))
                        .frame(height: 18, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(routine.name)
                            .font(.system(size: 22, weight: .semibold))
                            .frame(height: 25, alignment: .leading)
                            .lineLimit(1)
                        Text(routine.focus)
                            .font(.system(size: 16))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
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
        .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Routine \(routine.rotationIndex), \(routine.name), \(routine.focus)")
    }
}

#Preview {
    HomeView()
    .environment(SessionStore())
    .environment(RoutineOverridesStore())
    .environment(WashTheme())
    .preferredColorScheme(.dark)
}
