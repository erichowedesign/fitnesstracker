import SwiftUI

/// Rough first-pass detail for a completed History session + optional HealthKit link.
struct HistorySessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.glassPalette) private var palette
    let session: FinishedSession
    var listNumber: Int
    var thumbnailSlug: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(session.routineName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .glassInk()
                Text("Routine \(listNumber) · \(session.finishedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.body)
                    .glassInk(.secondary)
                    .padding(.top, 8)

                HStack(spacing: 16) {
                    IllustrationView(slug: thumbnailSlug, label: session.routineName)
                        .frame(width: 96, height: 96)
                        .saturation(0)
                        .opacity(0.9)
                    VStack(alignment: .leading, spacing: 8) {
                        detailStat(label: "Logged", value: "\(session.durationMinutes) min")
                        detailStat(label: "Sets", value: "\(session.totalSets)")
                        if session.hasHealthLink {
                            Label("Linked to Apple Health", systemImage: "heart.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.accent)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                .padding(.top, 24)

                if let link = session.healthLink {
                    Text("Watch / Health")
                        .font(.title2)
                        .fontWeight(.bold)
                        .glassInk()
                        .padding(.top, 48)

                    VStack(alignment: .leading, spacing: 12) {
                        healthRow("Type", link.activityName)
                        healthRow("Start", link.startedAt.formatted(date: .abbreviated, time: .shortened))
                        healthRow("End", link.endedAt.formatted(date: .abbreviated, time: .shortened))
                        healthRow("Duration", durationLabel(link.durationSeconds))
                        if let kcal = link.activeEnergyKcal {
                            healthRow("Active energy", "\(Int(kcal.rounded())) kcal")
                        }
                        if let avg = link.averageHeartRateBPM {
                            healthRow("Avg heart rate", "\(Int(avg.rounded())) bpm")
                        }
                        if let maxHR = link.maxHeartRateBPM {
                            healthRow("Max heart rate", "\(Int(maxHR.rounded())) bpm")
                        }
                        if let meters = link.totalDistanceMeters, meters > 0 {
                            healthRow("Distance", HealthWorkoutCandidate.formatDistance(meters: meters))
                        }
                        healthRow("Health UUID", String(link.workoutUUID.uuidString.prefix(8)) + "…")
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .padding(.top, 24)
                } else {
                    Text("No Watch / Health workout linked yet. Use Scan Health on History to find one.")
                        .font(.body)
                        .glassInk(.secondary)
                        .padding(.top, 48)
                }

                if !session.lifts.isEmpty {
                    Text("Lifts")
                        .font(.title2)
                        .fontWeight(.bold)
                        .glassInk()
                        .padding(.top, 48)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(session.lifts) { lift in
                            HStack {
                                Text(lift.name)
                                    .font(.body.weight(.semibold))
                                    .glassInk()
                                Spacer()
                                Text("\(lift.sets) × \(lift.weight)")
                                    .font(.body)
                                    .glassInk(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 34)
            .padding(.bottom, 48)
        }
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectHidden(true, for: .vertical)
        .glassInk()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color.black
                WashBackground(grade: .grayscale)
            }
            .ignoresSafeArea()
        }
        .containerBackground(.clear, for: .navigation)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .navigationTitle("Session")
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(palette.colorScheme)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                GlassChromeIconButton(
                    systemName: "chevron.backward",
                    accessibilityLabel: "Back",
                    action: { dismiss() }
                )
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                RootChromeLayout.menuSlot
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    private func detailStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .glassInk(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .glassInk()
        }
    }

    private func healthRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .glassInk(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.body.weight(.semibold))
                .glassInk()
                .multilineTextAlignment(.trailing)
        }
    }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let minutes = total / 60
        let rem = total % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes):\(String(format: "%02d", rem))"
    }
}
