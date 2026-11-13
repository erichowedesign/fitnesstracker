import SwiftUI

struct HistoryView: View {
    @Environment(SessionStore.self) private var store
    @Environment(WashTheme.self) private var wash
    @State private var expandedSessionID: UUID?
    @State private var draftWeights: [String: String] = [:]
    @State private var didResubmit = false
    @State private var updatePhase: CommitButton.Phase = .idle

    private var stats: HistoryStats { store.stats }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Progress")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("What you’ve logged on this iPhone")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 8)

                    dashboard
                        .padding(.top, 28)

                    Text("Recent Workouts")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 40)

                    if store.sessions.isEmpty {
                        OutcomeScreen(
                            outcome: .empty,
                            title: "No sessions yet",
                            message: "Complete a workout and it will show up here.",
                            primaryTitle: "Got it",
                            primaryAction: {},
                            style: OutcomeScreen.Style(
                                text: .white,
                                muted: .white.opacity(0.75)
                            )
                        )
                        .padding(.top, 12)
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
            .foregroundStyle(.white)
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
            }
            .toast(
                isPresented: $didResubmit,
                message: "Workout updated",
                detail: "Weights are saved for that session.",
                style: .success,
                position: .top
            )
        }
    }

    private var dashboard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                LiveStat(
                    label: "Workouts",
                    value: Double(stats.workoutsCompleted),
                    format: .number.precision(.fractionLength(0)),
                    style: LiveStatStyle(
                        background: .clear,
                        text: .white,
                        muted: .white.opacity(0.75),
                        line: .white.opacity(0.85),
                        accent: Color(red: 0, green: 0.569, blue: 1),
                        up: Color(red: 0, green: 0.77, blue: 0.655),
                        down: Color(red: 1, green: 0, blue: 0),
                        chipInk: .white,
                        numeralSize: 48
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 188)

                VStack(spacing: 12) {
                    glassModule {
                        VStack(alignment: .leading, spacing: 6) {
                            moduleLabel("This week")
                            Odometer(
                                value: Double(stats.thisWeek),
                                showsDelta: false
                            )
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                            Text("sessions")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    glassModule {
                        VStack(alignment: .leading, spacing: 6) {
                            moduleLabel("This month")
                            Odometer(
                                value: Double(stats.thisMonth),
                                showsDelta: false
                            )
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                            Text("sessions")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: 132)
                .frame(height: 188)
            }

            HStack(spacing: 12) {
                glassModule {
                    VStack(alignment: .leading, spacing: 8) {
                        moduleLabel("Streak")
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Odometer(
                                value: Double(stats.currentStreak),
                                showsDelta: false
                            )
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(.white)
                            Text(stats.currentStreak == 1 ? "day" : "days")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        Text(streakCopy)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)

                glassModule {
                    VStack(alignment: .leading, spacing: 8) {
                        moduleLabel("Time logged")
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Odometer(
                                value: Double(stats.totalMinutes) / 60,
                                format: .number.precision(.fractionLength(stats.totalMinutes < 600 ? 1 : 0)),
                                showsDelta: false
                            )
                            Text("h")
                        }
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.75)
                        Text("\(stats.totalMinutes) min total")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 148)
                .frame(height: 120)
            }

            glassModule {
                VStack(alignment: .leading, spacing: 14) {
                    moduleLabel("Routine mix")
                    if stats.routineMix.isEmpty {
                        Text("Finish a few workouts to see the split.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(stats.routineMix.prefix(4), id: \.name) { item in
                                routineMixRow(name: item.name, count: item.count)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var streakCopy: String {
        if stats.currentStreak == 0 {
            return "Start one today"
        }
        if stats.currentStreak == 1 {
            return "Keep it going"
        }
        return "On a roll"
    }

    private func moduleLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.8))
    }

    private func glassModule<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassSurface(.rect(cornerRadius: 28))
    }

    private func routineMixRow(name: String, count: Int) -> some View {
        let total = max(stats.workoutsCompleted, 1)
        let fraction = CGFloat(count) / CGFloat(total)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.subheadline)
                Spacer(minLength: 8)
                Text("\(count)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.8))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.12))
                    Capsule()
                        .fill(.white.opacity(0.85))
                        .frame(width: max(8, proxy.size.width * fraction))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(count) workouts")
    }

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
                            .foregroundStyle(.white)
                        Text(Self.dateLabel.string(from: session.finishedAt))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("\(session.durationMinutes) min")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.85))
                        Text("\(session.totalSets) sets")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 4)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()
                        .overlay(Color.white.opacity(0.18))

                    if session.lifts.isEmpty {
                        Text("No lifts were saved for this session.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    } else {
                        ForEach(session.lifts) { lift in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lift.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("\(lift.sets) sets")
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.65))
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
                                    .glassSurface(.rect(cornerRadius: 12))
                            }
                        }

                        CommitButton(
                            "Update weights",
                            phase: $updatePhase,
                            tint: Color(red: 0, green: 0.569, blue: 1),
                            tintInk: .white,
                            successTitle: "Saved",
                            collapses: false
                        ) {
                            updatePhase = .loading
                            resubmit(session)
                            updatePhase = .success
                        }
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
                updatePhase = .idle
            } else {
                expandedSessionID = session.id
                draftWeights = Dictionary(uniqueKeysWithValues: session.lifts.map { ($0.id, Self.poundsText(from: $0.weight)) })
                updatePhase = .idle
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
