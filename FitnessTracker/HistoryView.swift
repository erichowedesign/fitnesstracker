import SwiftUI

struct HistoryView: View {
    @Environment(SessionStore.self) private var store
    @Environment(WashTheme.self) private var wash
    @Environment(\.glassPalette) private var palette
    @State private var expandedSessionID: UUID?
    @State private var draftWeights: [String: String] = [:]
    @State private var didResubmit = false
    @State private var volumeRange: ClosedRange<Date> = Date()...Date()

    private var stats: HistoryStats { store.stats }
    private var accent: Color { palette.accent }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Progress")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("What you’ve logged on this iPhone")
                        .font(.body)
                        .glassInk(.secondary)
                        .padding(.top, 8)

                    liveStatRow
                        .padding(.top, 28)

                    volumeSection
                        .padding(.top, 28)

                    mixSection
                        .padding(.top, 28)

                    Text("Recent Workouts")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 40)

                    if store.sessions.isEmpty {
                        Text("Complete a workout and it will show up here.")
                            .font(.body)
                            .glassInk(.secondary)
                            .padding(.top, 20)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.sessions) { session in
                                sessionRow(session)
                            }
                        }
                        .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectHidden(true, for: .vertical)
            .contentMargins(.bottom, 120, for: .scrollContent)
            .glassInk()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(.clear, for: .navigation)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
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
                volumeRange = defaultVolumeWindow
            }
            .onChange(of: store.sessions.count) { _, _ in
                volumeRange = clamped(volumeRange)
            }
            .alert("Workout updated", isPresented: $didResubmit) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Weights are saved for that session.")
            }
        }
    }

    // MARK: - Stats

    private var liveStatRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("At a glance")
                .font(.title3)
                .fontWeight(.semibold)

            if store.sessions.isEmpty {
                chartEmpty("Log a workout to unlock these numbers.")
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    LiveStat(
                        label: "Workouts",
                        value: Double(stats.workoutsCompleted),
                        format: .number.precision(.fractionLength(0)),
                        series: cumulativeWorkoutSeries,
                        tint: accent,
                        style: liveStatStyle(numeral: 40)
                    )
                    .frame(minHeight: 148)

                    LiveStat(
                        label: "This week",
                        value: Double(stats.thisWeek),
                        format: .number.precision(.fractionLength(0)),
                        series: recentDailyWorkoutCounts,
                        tint: accent,
                        style: liveStatStyle(numeral: 34)
                    )
                    .frame(minHeight: 148)

                    LiveStat(
                        label: "Streak",
                        value: Double(stats.currentStreak),
                        format: .number.precision(.fractionLength(0)),
                        tint: accent,
                        style: liveStatStyle(numeral: 34)
                    )
                    .frame(minHeight: 132)

                    LiveStat(
                        label: "Hours",
                        value: Double(stats.totalMinutes) / 60,
                        format: .number.precision(.fractionLength(stats.totalMinutes < 600 ? 1 : 0)),
                        series: cumulativeMinutesSeries.map { $0 / 60 },
                        tint: accent,
                        style: liveStatStyle(numeral: 34)
                    )
                    .frame(minHeight: 132)
                }
            }
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volume")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Minutes trained by day")
                .font(.subheadline)
                .glassInk(.tertiary)

            if volumeSamples.count < 2 {
                chartEmpty("Finish a couple of workouts to chart volume over time.")
            } else {
                RangeLens(
                    samples: volumeSamples,
                    selection: $volumeRange,
                    summary: .total,
                    unit: "min",
                    minimumSpan: 7,
                    showsAverage: true,
                    style: RangeLens.Style(
                        accent: accent,
                        accentInk: palette.mode == .light ? palette.primary : .white,
                        text: palette.primary,
                        secondary: palette.secondary,
                        tertiary: palette.tertiary,
                        dim: palette.dim.opacity(1.5),
                        grid: palette.dim,
                        track: palette.dim.opacity(0.7),
                        chartHeight: 150,
                        numeralSize: 30
                    )
                )
                .padding(16)
                .frame(maxWidth: .infinity)
                .glassSurface(.rect(cornerRadius: 28))

                ScrubChart(
                    series: scrubSeries,
                    mode: .bars,
                    tint: accent,
                    format: ChartFormat.number.precision(.fractionLength(0)),
                    style: scrubStyle
                )
                .padding(16)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 260)
                .glassSurface(.rect(cornerRadius: 28))
            }
        }
    }

    private var mixSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Routine mix")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Share of completed sessions")
                .font(.subheadline)
                .glassInk(.tertiary)

            if stats.routineMix.isEmpty {
                chartEmpty("Finish a few workouts to see the split.")
            } else {
                RingBreakdown(
                    slices: mixSlices,
                    thickness: 32,
                    tint: accent,
                    format: ChartFormat.number.precision(.fractionLength(0)),
                    style: ringStyle
                )
                .padding(20)
                .frame(maxWidth: .infinity)
                .glassSurface(.rect(cornerRadius: 28))
            }
        }
    }

    private func chartEmpty(_ message: String) -> some View {
        Text(message)
            .font(.body)
            .glassInk(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .glassSurface(.rect(cornerRadius: 28))
    }

    // MARK: - Chart data (SessionStore)

    /// Daily minutes across the logged span (or last 60 days), for RangeLens.
    private var volumeSamples: [RangeLens.Sample] {
        dailyTotals(metric: .minutes, days: volumeDayCount).map {
            RangeLens.Sample(date: $0.date, value: $0.value)
        }
    }

    private typealias ChartFormat = FloatingPointFormatStyle<Double>
    private typealias ScrubPoint = ScrubChart<ChartFormat>.Point
    private typealias ScrubSeries = ScrubChart<ChartFormat>.Series
    private typealias MixSlice = RingBreakdown<ChartFormat>.Slice

    private var scrubSeries: [ScrubSeries] {
        let workouts = dailyTotals(metric: .workouts, days: 28).map {
            ScrubPoint(date: $0.date, value: $0.value)
        }
        let minutes = dailyTotals(metric: .minutes, days: 28).map {
            ScrubPoint(date: $0.date, value: $0.value)
        }
        return [
            ScrubSeries(label: "Workouts", points: workouts),
            ScrubSeries(label: "Minutes", points: minutes),
        ]
    }

    private var mixSlices: [MixSlice] {
        stats.routineMix.map { item in
            MixSlice(label: item.name, value: Double(item.count))
        }
    }

    private var cumulativeWorkoutSeries: [Double] {
        cumulativeSeries { _ in 1 }
    }

    private var cumulativeMinutesSeries: [Double] {
        cumulativeSeries { Double($0.durationMinutes) }
    }

    private var recentDailyWorkoutCounts: [Double] {
        dailyTotals(metric: .workouts, days: 14).map(\.value)
    }

    private var volumeDayCount: Int {
        max(spanDays, 14)
    }

    private var spanDays: Int {
        guard let oldest = store.sessions.map(\.finishedAt).min() else { return 14 }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: oldest), to: Calendar.current.startOfDay(for: Date())).day ?? 14
        return min(max(days + 1, 14), 90)
    }

    private var defaultVolumeWindow: ClosedRange<Date> {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -13, to: end) ?? end
        return clamped(start...end)
    }

    private func clamped(_ range: ClosedRange<Date>) -> ClosedRange<Date> {
        guard let first = volumeSamples.first?.date, let last = volumeSamples.last?.date else {
            return range
        }
        let lower = max(range.lowerBound, first)
        let upper = min(range.upperBound, last)
        if lower <= upper { return lower...upper }
        return first...last
    }

    private enum DailyMetric { case workouts, minutes }

    private func dailyTotals(metric: DailyMetric, days: Int) -> [(date: Date, value: Double)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        var buckets: [Date: Double] = [:]
        for offset in 0..<days {
            if let day = cal.date(byAdding: .day, value: offset, to: start) {
                buckets[day] = 0
            }
        }
        for session in store.sessions {
            let day = cal.startOfDay(for: session.finishedAt)
            guard day >= start else { continue }
            switch metric {
            case .workouts: buckets[day, default: 0] += 1
            case .minutes: buckets[day, default: 0] += Double(session.durationMinutes)
            }
        }
        return buckets.keys.sorted().map { ($0, buckets[$0] ?? 0) }
    }

    private func cumulativeSeries(_ contribution: (FinishedSession) -> Double) -> [Double] {
        let ordered = store.sessions.sorted { $0.finishedAt < $1.finishedAt }
        var running = 0.0
        var values: [Double] = []
        for session in ordered {
            running += contribution(session)
            values.append(running)
        }
        return values
    }

    // MARK: - Styles

    private func liveStatStyle(numeral: CGFloat) -> LiveStatStyle {
        LiveStatStyle(
            background: .clear,
            text: palette.primary,
            muted: palette.tertiary,
            line: accent,
            accent: accent,
            up: Color(red: 0, green: 0.77, blue: 0.655),
            down: Color(red: 1, green: 0.35, blue: 0.35),
            chipInk: palette.mode == .light ? palette.primary : .white,
            numeralSize: numeral
        )
    }

    private var scrubStyle: ScrubChartStyle {
        ScrubChartStyle(
            line: palette.primary.opacity(0.9),
            accent: accent,
            up: Color(red: 0, green: 0.77, blue: 0.655),
            down: Color(red: 1, green: 0.35, blue: 0.35),
            ink: palette.primary,
            muted: palette.tertiary,
            band: palette.dim,
            ground: palette.mode == .light ? Color.white.opacity(0.35) : Color.black.opacity(0.35),
            numeralSize: 36
        )
    }

    private var ringStyle: RingBreakdownStyle {
        RingBreakdownStyle(
            blocks: [
                accent,
                Color(red: 0.45, green: 0.9, blue: 0.35),
                Color(red: 1, green: 0.76, blue: 0.2),
                Color(red: 1, green: 0.45, blue: 0.25),
                Color(red: 0.55, green: 0.75, blue: 1),
                Color(red: 0.95, green: 0.95, blue: 0.95),
            ],
            rest: palette.dim.opacity(1.3),
            ink: palette.mode == .light ? .white : Color(red: 0.08, green: 0.08, blue: 0.08),
            text: palette.primary,
            muted: palette.tertiary
        )
    }

    // MARK: - Sessions list

    private func sessionRow(_ session: FinishedSession) -> some View {
        let expanded = expandedSessionID == session.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                toggle(session)
            } label: {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.routineName)
                            .font(.headline)
                            .glassInk()
                        Text(Self.dateLabel.string(from: session.finishedAt))
                            .font(.subheadline)
                            .glassInk(.secondary)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("\(session.durationMinutes) min")
                            .font(.subheadline)
                            .monospacedDigit()
                            .glassInk(.secondary)
                        Text("\(session.totalSets) sets")
                            .font(.footnote)
                            .glassInk(.tertiary)
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .glassInk(.tertiary)
                        .padding(.top, 4)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()
                        .overlay(palette.dim)

                    if session.lifts.isEmpty {
                        Text("No lifts were saved for this session.")
                            .font(.subheadline)
                            .glassInk(.secondary)
                    } else {
                        ForEach(session.lifts) { lift in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lift.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("\(lift.sets) sets")
                                        .font(.footnote)
                                        .glassInk(.tertiary)
                                }
                                Spacer(minLength: 12)
                                TextField("lbs", text: weightBinding(for: lift.id, fallback: lift.weight))
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .frame(width: 88)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(palette.dim.opacity(0.7))
                                    )
                            }
                        }

                        Button {
                            resubmit(session)
                        } label: {
                            Text("Update weights")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .buttonBorderShape(.capsule)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .glassSurface(.rect(cornerRadius: 28))
        .animation(.smooth(duration: 0.28), value: expanded)
    }

    private func toggle(_ session: FinishedSession) {
        withAnimation(.smooth(duration: 0.28)) {
            if expandedSessionID == session.id {
                expandedSessionID = nil
                draftWeights = [:]
            } else {
                expandedSessionID = session.id
                draftWeights = Dictionary(uniqueKeysWithValues: session.lifts.map { ($0.id, Self.poundsText(from: $0.weight)) })
            }
        }
    }

    private func weightBinding(for id: String, fallback: String) -> Binding<String> {
        Binding(
            get: { draftWeights[id] ?? Self.poundsText(from: fallback) },
            set: { draftWeights[id] = Self.filterPounds($0) }
        )
    }

    private func resubmit(_ session: FinishedSession) {
        var updated = session
        updated.lifts = session.lifts.map { lift in
            var next = lift
            if let draft = draftWeights[lift.id], let formatted = Self.formattedWeight(from: draft) {
                next.weight = formatted
            }
            return next
        }
        store.update(updated)
        didResubmit = true
        withAnimation(.smooth(duration: 0.28)) {
            expandedSessionID = nil
            draftWeights = [:]
        }
    }

    private static let dateLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static func poundsText(from display: String) -> String {
        display.replacingOccurrences(of: "lbs", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func filterPounds(_ value: String) -> String {
        var result = ""
        var sawDot = false
        for character in value {
            if character.isNumber {
                result.append(character)
            } else if character == ".", !sawDot {
                result.append(character)
                sawDot = true
            }
        }
        return result
    }

    private static func formattedWeight(from draft: String) -> String? {
        let cleaned = draft.trimmingCharacters(in: .whitespaces)
        if cleaned == "—" || cleaned.isEmpty { return cleaned.isEmpty ? nil : cleaned }
        guard let value = Double(cleaned) else { return nil }
        if value.rounded() == value {
            return "\(Int(value)) lbs"
        }
        return String(format: "%.1f lbs", value)
    }
}

#Preview {
    HistoryView()
        .environment(SessionStore())
        .environment(WashTheme())
        .preferredColorScheme(.dark)
}
