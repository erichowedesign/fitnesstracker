import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var store
    @Environment(WashTheme.self) private var wash
    private let routines = WorkoutPlan.all()

    private var upNext: Routine {
        store.nextRoutine(in: routines)
    }

    private var myRoutines: [Routine] {
        store.remainingRoutines(after: upNext, in: routines)
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
                        NavigationLink(value: routine) {
                            RoutineListCard(routine: routine)
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
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("More")
            }
        }
        .navigationDestination(for: Routine.self) { routine in
            RoutineView(routine: routine)
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

private struct UpNextCard: View {
    let routine: Routine

    var body: some View {
        ZStack(alignment: .topLeading) {
            IllustrationView(slug: routine.heroSlug, label: routine.name)
                .frame(width: 210, height: 210)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 28)
                .padding(.trailing, 20)

            Text("Routine \(routine.rotationIndex)")
                .font(.subheadline)
                .padding(.top, 22)
                .padding(.leading, 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name)
                    .font(.title)
                    .fontWeight(.bold)
                Text(routine.focus)
                    .font(.body)
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
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(routine.name), \(routine.focus), \(routine.workoutsLine)")
    }
}

private struct RoutineListCard: View {
    let routine: Routine

    var body: some View {
        HStack(spacing: 20) {
            IllustrationView(slug: routine.heroSlug, label: routine.name)
                .frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.focus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(routine.name)
                    .font(.headline)
                Text("\(routine.exerciseCountLabel) workouts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 152)
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(routine.name), \(routine.focus), \(routine.exerciseCountLabel) workouts")
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
