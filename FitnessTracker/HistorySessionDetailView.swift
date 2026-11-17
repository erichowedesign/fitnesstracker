import SwiftUI

/// Completed History session detail — lifts plus an Apple Health–style workout summary when linked.
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
                    Text("Workout")
                        .font(.title2)
                        .fontWeight(.bold)
                        .glassInk()
                        .padding(.top, 48)

                    HealthWorkoutSummaryView(link: link)
                        .padding(.top, 16)
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
}

// MARK: - Apple Health–style workout summary

/// Layout/typography inspired by the Health app workout detail: hero Total Time + colored metric grid.
private struct HealthWorkoutSummaryView: View {
    let link: LinkedHealthWorkout

    private var timeRangeLine: String {
        let day = link.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
        let start = link.startedAt.formatted(date: .omitted, time: .shortened)
        let end = link.endedAt.formatted(date: .omitted, time: .shortened)
        return "\(day) · \(start)–\(end)"
    }

    private var gridMetrics: [HealthSummaryMetric] {
        var rows: [HealthSummaryMetric] = []
        if let kcal = link.activeEnergyKcal {
            rows.append(
                HealthSummaryMetric(
                    id: "energy",
                    title: "Active Energy",
                    value: "\(Int(kcal.rounded()))",
                    unit: "CAL",
                    systemImage: "flame.fill",
                    tint: HealthSummaryPalette.energy
                )
            )
        }
        if let avg = link.averageHeartRateBPM {
            rows.append(
                HealthSummaryMetric(
                    id: "avgHR",
                    title: "Avg. Heart Rate",
                    value: "\(Int(avg.rounded()))",
                    unit: "BPM",
                    systemImage: "heart.fill",
                    tint: HealthSummaryPalette.heart
                )
            )
        }
        if let maxHR = link.maxHeartRateBPM {
            rows.append(
                HealthSummaryMetric(
                    id: "maxHR",
                    title: "Max. Heart Rate",
                    value: "\(Int(maxHR.rounded()))",
                    unit: "BPM",
                    systemImage: "heart.fill",
                    tint: HealthSummaryPalette.heart
                )
            )
        }
        if let meters = link.totalDistanceMeters, meters > 0 {
            let formatted = HealthWorkoutCandidate.formatDistance(meters: meters)
            let parts = formatted.split(separator: " ")
            let value = parts.first.map(String.init) ?? formatted
            let unit = parts.dropFirst().first.map { String($0).uppercased() } ?? "MI"
            rows.append(
                HealthSummaryMetric(
                    id: "distance",
                    title: "Distance",
                    value: value,
                    unit: unit,
                    systemImage: "figure.walk",
                    tint: HealthSummaryPalette.distance
                )
            )
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            totalTimeHero
                .padding(.top, 28)
            if !gridMetrics.isEmpty {
                metricsGrid
                    .padding(.top, 8)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Apple Health workout summary, \(link.activityName)")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(HealthSummaryPalette.workout.opacity(0.22))
                    .frame(width: 52, height: 52)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(HealthSummaryPalette.workout)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(link.activityName)
                    .font(.title3.weight(.semibold))
                    .glassInk()
                Text(timeRangeLine)
                    .font(.subheadline)
                    .glassInk(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var totalTimeHero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Total Time")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HealthSummaryPalette.workout)
            Text(HealthSummaryFormatting.durationDisplay(link.durationSeconds))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .glassInk()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(HealthSummaryFormatting.durationCaption(link.durationSeconds))
                .font(.footnote)
                .glassInk(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total time, \(HealthSummaryFormatting.durationCaption(link.durationSeconds))")
    }

    private var metricsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
            ForEach(gridMetrics) { metric in
                HealthSummaryMetricCell(metric: metric)
            }
        }
        .padding(.top, 20)
    }
}

private struct HealthSummaryMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let tint: Color
}

private struct HealthSummaryMetricCell: View {
    let metric: HealthSummaryMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: metric.systemImage)
                    .font(.caption.weight(.bold))
                Text(metric.title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(metric.tint)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(metric.value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .glassInk()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(metric.unit)
                    .font(.caption.weight(.semibold))
                    .glassInk(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.title), \(metric.value) \(metric.unit)")
    }
}

private enum HealthSummaryPalette {
    /// Matches Health’s workout / activity accent (teal-green).
    static let workout = Color(red: 0.20, green: 0.78, blue: 0.64)
    /// Active Energy — Health orange.
    static let energy = Color(red: 1.00, green: 0.58, blue: 0.00)
    /// Heart Rate — Health red/pink.
    static let heart = Color(red: 1.00, green: 0.22, blue: 0.37)
    /// Distance — Health blue.
    static let distance = Color(red: 0.04, green: 0.52, blue: 1.00)
}

private enum HealthSummaryFormatting {
    /// Large hero string like Health: `1:12:34` or `42:08`.
    static func durationDisplay(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func durationCaption(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours) hr \(minutes) min \(secs) sec"
        }
        if minutes > 0 {
            return "\(minutes) min \(secs) sec"
        }
        return "\(secs) sec"
    }
}
