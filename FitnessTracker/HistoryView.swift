import SwiftUI

struct HistoryView: View {
    @Environment(SessionStore.self) private var store
    @Environment(RoutineOverridesStore.self) private var routineOverrides
    @Environment(CustomRoutinesStore.self) private var customRoutines
    @Environment(RoutineOrderStore.self) private var routineOrder
    @Environment(WashTheme.self) private var wash
    @Environment(\.glassPalette) private var palette

    private var shippingRoutines: [Routine] {
        WorkoutPlan.all().map(routineOverrides.resolved)
    }

    private var orderedCatalog: [Routine] {
        routineOrder.ordered(
            shipping: shippingRoutines,
            customs: customRoutines.routines(startingRotationAt: shippingRoutines.count + 1)
        )
    }

    /// Newest completed sessions first (SessionStore already inserts at 0).
    private var sessionsNewestFirst: [FinishedSession] {
        store.sessions.sorted { $0.finishedAt > $1.finishedAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("History")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .glassInk()
                    Text("Workouts you’ve completed on this iPhone")
                        .font(.body)
                        .glassInk()
                        .padding(.top, 8)

                    if sessionsNewestFirst.isEmpty {
                        Text("Complete a workout and it will show up here.")
                            .font(.body)
                            .glassInk(.secondary)
                            .padding(.top, 48)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(sessionsNewestFirst) { session in
                                CompletedSessionCard(
                                    session: session,
                                    listNumber: listNumber(for: session.routineId),
                                    thumbnailSlug: thumbnailSlug(for: session)
                                )
                            }
                        }
                        .padding(.top, 48)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 34)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectHidden(true, for: .vertical)
            .contentMargins(.bottom, 120, for: .scrollContent)
            .glassInk()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(.clear, for: .navigation)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .preferredColorScheme(palette.colorScheme)
            .animation(.smooth(duration: 0.3), value: palette.mode)
            .background { LockRootPopGesture() }
            .navigationTitle("History")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("History")
                        .opacity(0)
                        .accessibilityHidden(true)
                }
            }
            .onAppear {
                wash.grade = .grayscale
            }
        }
    }

    private func listNumber(for routineID: String) -> Int {
        (orderedCatalog.firstIndex { $0.id == routineID } ?? 0) + 1
    }

    private func thumbnailSlug(for session: FinishedSession) -> String {
        if let routine = orderedCatalog.first(where: { $0.id == session.routineId }) {
            return routine.thumbnailSlug
        }
        return WorkoutPlan.all().first(where: { $0.id == session.routineId })?.thumbnailSlug
            ?? "bodyweight-squat"
    }
}

/// Home My Routines tile language: thumb + routine number/name, grayscale wash, check + date.
private struct CompletedSessionCard: View {
    @Environment(\.glassPalette) private var palette

    let session: FinishedSession
    var listNumber: Int
    var thumbnailSlug: String

    private var completedStamp: String {
        session.finishedAt.formatted(
            .dateTime
                .weekday(.abbreviated)
                .month(.abbreviated)
                .day()
                .hour()
                .minute()
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    WashWindow(grade: .grayscale)
                        .clipShape(historyIllustrationThumb(gap: 16))
                    IllustrationView(slug: thumbnailSlug, label: session.routineName)
                        .frame(width: 120, height: 120)
                        .saturation(0)
                        .opacity(0.88)
                }
                .frame(width: 120, height: 120)
                .clipShape(historyIllustrationThumb(gap: 16))
                .glassInk()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, palette.accent)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    .offset(x: 4, y: 4)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 23) {
                Text("Routine \(listNumber)")
                    .font(.system(size: 15))
                    .frame(height: 18, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.routineName)
                        .font(.system(size: 22, weight: .semibold))
                        .frame(height: 25, alignment: .leading)
                        .lineLimit(1)
                    Text(completedStamp)
                        .font(.system(size: 16))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .glassInk(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassInk()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 152)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Completed Routine \(listNumber), \(session.routineName), \(completedStamp)"
        )
    }
}

private func historyIllustrationThumb(gap: CGFloat) -> RoundedRectangle {
    RoundedRectangle(cornerRadius: 34 - gap, style: .continuous)
}

#Preview {
    HistoryView()
        .environment(SessionStore())
        .environment(RoutineOverridesStore())
        .environment(CustomRoutinesStore())
        .environment(RoutineOrderStore())
        .environment(WashTheme())
        .environment(GlassModeStore())
}
