import SwiftUI

/// History rescan: find Health workouts in a timeframe and confirm which sessions to link.
struct HistoryHealthScanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var store
    @Environment(\.glassPalette) private var palette

    @State private var healthImport = HealthImportStore()
    @State private var days = 7
    @State private var candidates: [HealthWorkoutCandidate] = []
    @State private var selectedSessionByWorkout: [UUID: UUID] = [:]
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var didScan = false

    private var unlinkedSessions: [FinishedSession] {
        store.sessions
            .filter { $0.healthLink == nil }
            .sorted { $0.finishedAt > $1.finishedAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Scan Health")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .glassInk()
                    Text("Find Watch / Health workouts and link them to completed Foundation sessions.")
                        .font(.body)
                        .glassInk(.secondary)
                        .padding(.top, 8)

                    Picker("Timeframe", selection: $days) {
                        Text("1 day").tag(1)
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 24)

                    Button {
                        Task { await scan() }
                    } label: {
                        Text(isScanning ? "Scanning…" : "Scan")
                            .font(.title3.weight(.semibold))
                            .glassInk()
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.plain)
                    .foundationGlass(interactive: true, in: Capsule())
                    .disabled(isScanning)
                    .padding(.top, 24)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.top, 16)
                    }

                    if didScan, candidates.isEmpty, errorMessage == nil {
                        Text("No Health workouts found in that timeframe.")
                            .font(.body)
                            .glassInk(.secondary)
                            .padding(.top, 24)
                    }

                    if !candidates.isEmpty {
                        Text("Matches")
                            .font(.title2)
                            .fontWeight(.bold)
                            .glassInk()
                            .padding(.top, 48)

                        VStack(spacing: 12) {
                            ForEach(candidates) { candidate in
                                candidateCard(candidate)
                            }
                        }
                        .padding(.top, 24)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .glassInk()
            .background {
                ZStack {
                    Color.black
                    WashBackground(grade: .grayscale)
                }
                .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GlassChromeLabelButton(title: "Done", action: { dismiss() })
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) {
                    RootChromeMenu()
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .preferredColorScheme(palette.colorScheme)
        }
    }

    private func candidateCard(_ candidate: HealthWorkoutCandidate) -> some View {
        let alreadyLinked = HealthSessionMatching.linkedWorkoutUUIDs(in: store.sessions)
            .contains(candidate.workoutUUID)
        let suggested = HealthSessionMatching.suggestedSession(for: candidate, in: store.sessions)
        let selectedID = selectedSessionByWorkout[candidate.workoutUUID] ?? suggested?.id

        return VStack(alignment: .leading, spacing: 12) {
            Text(candidate.summaryLine)
                .font(.headline)
                .glassInk()
            Text("\(candidate.startedAt.formatted(date: .abbreviated, time: .shortened)) → \(candidate.endedAt.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .glassInk(.secondary)

            if alreadyLinked {
                Text("Already linked to a Foundation session.")
                    .font(.subheadline)
                    .foregroundStyle(palette.accent)
            } else if unlinkedSessions.isEmpty {
                Text("No unlinked History sessions to attach.")
                    .font(.subheadline)
                    .glassInk(.secondary)
            } else {
                Picker(
                    "Session",
                    selection: Binding(
                        get: { selectedID ?? unlinkedSessions[0].id },
                        set: { selectedSessionByWorkout[candidate.workoutUUID] = $0 }
                    )
                ) {
                    ForEach(unlinkedSessions) { session in
                        Text("\(session.routineName) · \(session.finishedAt.formatted(date: .abbreviated, time: .shortened))")
                            .tag(session.id)
                    }
                }
                .labelsHidden()

                Button {
                    guard let sessionID = selectedSessionByWorkout[candidate.workoutUUID] ?? suggested?.id
                        ?? unlinkedSessions.first?.id
                    else { return }
                    store.linkHealth(candidate.asLinkedHealthWorkout, to: sessionID)
                } label: {
                    Text("Link to session")
                        .font(.body.weight(.semibold))
                        .glassInk()
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .foundationGlass(interactive: true, in: Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @MainActor
    private func scan() async {
        isScanning = true
        errorMessage = nil
        defer { isScanning = false }
        do {
            let found = try await healthImport.workouts(inLastDays: days)
            candidates = found
            didScan = true
            var preset: [UUID: UUID] = [:]
            for candidate in found {
                if let suggested = HealthSessionMatching.suggestedSession(for: candidate, in: store.sessions) {
                    preset[candidate.workoutUUID] = suggested.id
                }
            }
            selectedSessionByWorkout = preset
        } catch {
            errorMessage = error.localizedDescription
            candidates = []
            didScan = true
        }
    }
}
