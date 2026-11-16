import SwiftUI

struct ExerciseTutorial: Hashable, Identifiable {
    var id: String { "\(sectionTitle)-\(favoriteSlug ?? name)-\(dose?.itemID ?? "tips")" }
    let name: String
    let muscles: String
    let frames: [String]
    let hints: [String]
    let hintSource: String?
    let favoriteSlug: String?
    /// Centered nav title from the routine section, or "Tutorial" from Library.
    let sectionTitle: String
    /// When set, show Weight / Reps-or-Time / Sets tap steppers and persist changes.
    let dose: RoutineDoseFields?
}

struct RoutineDoseFields: Hashable {
    enum Section: Hashable {
        case warmup
        case main
        case cooldown
    }

    var itemID: String
    var section: Section
    var weightLbs: Int
    /// Reps, or seconds when `usesDuration` is true.
    var reps: Int
    var sets: Int
    var usesDuration: Bool = false
}

struct ExerciseTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FavoritesStore.self) private var favorites
    @Environment(\.glassPalette) private var palette
    let exerciseName: String
    let muscles: String
    let frames: [String]
    let hints: [String]
    let hintSource: String?
    /// Library tutorials default to black grayscale; routine tutorials pass the routine wash.
    var grade: WashGrade = .grayscale
    var favoriteSlug: String? = nil
    var sectionTitle: String = "Tutorial"
    var initialDose: RoutineDoseFields? = nil
    var onDoseChange: ((RoutineDoseFields) -> Void)? = nil

    @State private var weightLbs = 0
    @State private var reps = 10
    @State private var sets = 3
    @State private var didLoadDose = false

    private var canFavorite: Bool { favoriteSlug != nil }
    private var showsDoseAdjusters: Bool { initialDose != nil }
    private var isLiked: Bool {
        guard let favoriteSlug else { return false }
        return favorites.isLiked(favoriteSlug)
    }

    /// Colorless liquid glass — glyphs/ink follow the active glass palette.
    private var clearStepperStyle: ScrubStepper.Style {
        ScrubStepper.Style(
            button: .clear,
            glyph: palette.primary,
            block: .clear,
            ink: palette.primary,
            height: 52
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(exerciseName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .glassInk()
                    .fixedSize(horizontal: false, vertical: true)
                Text(muscles)
                    .font(.body)
                    .glassInk()
                    .padding(.top, 8)

                cyclingHero
                    .padding(.top, 24)

                if showsDoseAdjusters {
                    doseRows
                        .padding(.top, 24)
                }

                Text("Tips & Hints")
                    .font(.title2)
                    .fontWeight(.bold)
                    .glassInk()
                    .padding(.top, showsDoseAdjusters ? 48 : 48)

                if let hintSource, !hints.isEmpty {
                    Text("Source: \(hintSource)")
                        .font(.subheadline)
                        .glassInk(.tertiary)
                        .padding(.top, 8)
                }

                VStack(spacing: 12) {
                    ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                        hintCard(hint)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 16)
            // Match Home / History / Routine large-title top inset.
            .padding(.top, 34)
        }
        .scrollContentBackground(.hidden)
        .glassInk()
        .background {
            ZStack {
                Color.black
                WashBackground(grade: grade)
            }
            .ignoresSafeArea()
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .navigationTitle(sectionTitle)
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(palette.colorScheme)
        .animation(.smooth(duration: 0.3), value: palette.mode)
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
                HStack(spacing: RootChromeLayout.trailingClusterSpacing) {
                    if canFavorite {
                        GlassChromeIconButton(
                            systemName: isLiked ? "heart.fill" : "heart",
                            accessibilityLabel: isLiked ? "Remove from favorites" : "Add to favorites",
                            ink: isLiked ? palette.heart : nil,
                            action: {
                                guard let favoriteSlug else { return }
                                favorites.toggle(favoriteSlug)
                            }
                        )
                    }
                    RootChromeLayout.menuSlot
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .background {
            DisableRoutineInteractivePop()
        }
        .onAppear(perform: loadDoseIfNeeded)
        .onChange(of: weightLbs) { _, _ in emitDoseChange() }
        .onChange(of: reps) { _, _ in emitDoseChange() }
        .onChange(of: sets) { _, _ in emitDoseChange() }
    }

    private var usesDurationDose: Bool {
        initialDose?.usesDuration == true
    }

    private var doseRows: some View {
        VStack(spacing: 12) {
            doseRow(label: "Weight") {
                ScrubStepper(value: $weightLbs, in: 0...500, step: 5, allowsScrubbing: false, style: clearStepperStyle)
                    .accessibilityLabel("Weight")
            }
            if usesDurationDose {
                doseRow(label: "Time") {
                    ScrubStepper(
                        value: $reps,
                        in: Self.durationRange,
                        step: Self.durationStepSeconds,
                        allowsScrubbing: false,
                        formatValue: Self.formatDurationClock,
                        // Wide enough for `10:00` monospaced in the pill (default 72 truncates `m:ss`).
                        minimumWellWidth: 108,
                        style: clearStepperStyle
                    )
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel("Time")
                }
            } else {
                doseRow(label: "Reps") {
                    ScrubStepper(value: $reps, in: 1...50, step: 1, allowsScrubbing: false, style: clearStepperStyle)
                        .accessibilityLabel("Reps")
                }
            }
            doseRow(label: "Sets") {
                ScrubStepper(value: $sets, in: 1...20, step: 1, allowsScrubbing: false, style: clearStepperStyle)
                    .accessibilityLabel("Sets")
            }
        }
    }

    private func doseRow<Content: View>(label: String, @ViewBuilder control: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.headline)
                .glassInk()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            Spacer(minLength: 0)
            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cyclingHero: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { context in
            let index = frames.isEmpty
                ? 0
                : Int(context.date.timeIntervalSinceReferenceDate / 0.45) % frames.count
            IllustrationView(slug: frames[index], label: exerciseName)
                .padding(28)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 370)
        .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private func hintCard(_ hint: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .glassInk()
                .frame(width: 22, height: 22)
            Text(hint)
                .font(.body)
                .glassInk()
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private func loadDoseIfNeeded() {
        guard !didLoadDose, let initialDose else { return }
        weightLbs = initialDose.weightLbs
        if initialDose.usesDuration {
            reps = Self.snappedDurationSeconds(initialDose.reps)
        } else {
            reps = max(initialDose.reps, 1)
        }
        sets = max(initialDose.sets, 1)
        // Defer so onChange from seed values does not write immediately.
        DispatchQueue.main.async { didLoadDose = true }
    }

    private func emitDoseChange() {
        guard didLoadDose, var dose = initialDose else { return }
        dose.weightLbs = weightLbs
        dose.reps = dose.usesDuration ? Self.snappedDurationSeconds(reps) : reps
        dose.sets = sets
        onDoseChange?(dose)
    }

    /// Time scrubber: ±15s, shown as `m:ss` (e.g. 1:30).
    private static let durationStepSeconds = 15
    private static let durationRange = durationStepSeconds...(60 * 10)

    private static func formatDurationClock(_ seconds: Int) -> String {
        let clamped = max(seconds, 0)
        return "\(clamped / 60):\(String(format: "%02d", clamped % 60))"
    }

    private static func snappedDurationSeconds(_ seconds: Int) -> Int {
        let step = durationStepSeconds
        let clamped = min(max(seconds, durationRange.lowerBound), durationRange.upperBound)
        let snapped = Int((Double(clamped) / Double(step)).rounded()) * step
        return min(max(snapped, durationRange.lowerBound), durationRange.upperBound)
    }
}
