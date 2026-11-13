import SwiftUI
import UIKit

struct UpperPushView: View {
    var body: some View {
        RoutineView(routine: WorkoutPlan.upperPush())
    }
}

struct RoutineView: View {
    @Environment(SessionStore.self) private var store
    let routine: Routine
    var hero: Namespace.ID? = nil
    var heroMatchEnabled: Bool = false
    @State private var didSave = false
    @State private var showCompleteButton = false
    @State private var openWeightRowID: String?
    @State private var editingWeightRowID: String?
    @State private var weightDraft = ""
    @State private var weights: [String: String] = [:]
    @State private var tutorial: ExerciseTutorial?

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(routine.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .homeHeroMatch("title-\(routine.id)", in: hero, isSource: false, enabled: heroMatchEnabled)
                    Text(routine.focus)
                        .font(.body)
                        .homeHeroMatch("focus-\(routine.id)", in: hero, isSource: false, enabled: heroMatchEnabled)
                        .padding(.top, 8)

                    RoutineHeroCycle(exercises: routine.exercises)
                        .frame(maxWidth: .infinity)
                        .frame(height: 370)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .homeHeroMatch("hero-art-\(routine.id)", in: hero, isSource: false, enabled: heroMatchEnabled)
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .padding(.top, 32)

                    glanceCard
                        .padding(.top, 16)

                    Text(routine.summary)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 48)

                    section("Warm-up", steps: routine.warmup, revealsCompleteButton: true)
                    mainWorkoutSection
                    section("Cool Down", steps: routine.cooldown)

                    credit
                        .padding(.top, 32)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 34)
                .padding(.bottom, 88)
            }
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .foregroundStyle(.white)
        .background {
            ZStack {
                Color.black
                WashBackground(grade: WashGrade.forRoutine(routine.id))
            }
            .ignoresSafeArea()
        }
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            ZStack {
                if showCompleteButton {
                    completeWorkoutButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.4), value: showCompleteButton)
        }
        .navigationTitle("Routine \(routine.rotationIndex)")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if hero != nil, heroMatchEnabled {
                ToolbarItem(placement: .principal) {
                    Text("Routine \(routine.rotationIndex)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .homeHeroMatch("eyebrow-\(routine.id)", in: hero, isSource: false, enabled: heroMatchEnabled)
                }
            }
        }
        .alert("Workout saved", isPresented: $didSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(routine.name) is stored on this iPhone.")
        }
        .background {
            DisableRoutineInteractivePop()
        }
        .navigationDestination(item: $tutorial) { item in
            ExerciseTutorialView(
                exerciseName: item.name,
                muscles: item.muscles,
                grade: WashGrade.forRoutine(routine.id),
                frames: item.frames,
                hints: item.hints,
                hintSource: item.hintSource
            )
        }
    }

    private static var screenMidY: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        return (scene?.screen.bounds.height ?? 0) / 2
    }

    private var glanceCard: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 16)
            HStack(alignment: .top, spacing: 56) {
                VStack(alignment: .leading, spacing: 8) {
                    glanceLabel("exercises")
                    glanceNumber(routine.exerciseCountLabel)
                }
                VStack(alignment: .leading, spacing: 8) {
                    glanceLabel("minutes")
                    glanceNumber("\(routine.minutes)")
                }
                VStack(spacing: 8) {
                    glanceLabel("difficulty")
                    DifficultyBars(filled: routine.difficulty)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 52)
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(routine.exercises.count) exercises, \(routine.minutes) minutes, difficulty \(routine.difficulty) of five")
    }

    private func glanceLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .frame(height: 16, alignment: .leading)
    }

    private func glanceNumber(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 34, weight: .semibold))
            .monospacedDigit()
            .frame(height: 41, alignment: .leading)
    }

    private var completeWorkoutButton: some View {
        Button {
            store.complete(routine, weights: weights)
            didSave = true
        } label: {
            Text("Complete Workout")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .controlSize(.extraLarge)
        .buttonBorderShape(.capsule)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func section(_ title: String, steps: [GuideStep], revealsCompleteButton: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { _, frame in
                    guard revealsCompleteButton, frame.height > 1 else { return }
                    showCompleteButton = frame.minY <= Self.screenMidY
                }
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    ForEach(steps) { step in
                        GuideRow(title: step.title, metaParts: step.metaParts, slug: step.slug)
                            .contentShape(Rectangle())
                            .onTapGesture { openTutorial(step) }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint("Opens the tutorial")
                    }
                }
            }
        }
        .padding(.top, 48)
    }

    private var mainWorkoutSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Main Workout")
                .font(.title2)
                .fontWeight(.bold)
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    ForEach(routine.exercises) { exercise in
                        MainWorkoutRow(
                            exercise: exercise,
                            weight: weights[exercise.id] ?? exercise.displayWeight ?? "—",
                            isOpen: openWeightRowID == exercise.id,
                            isEditing: editingWeightRowID == exercise.id,
                            weightDraft: $weightDraft,
                            onOpen: { openWeightRow(exercise.id) },
                            onClose: { closeWeightRow(exercise.id) },
                            onEdit: { beginWeightEdit(exercise) },
                            onCancel: { cancelWeightRow(exercise.id) },
                            onSelect: { openTutorial(exercise) }
                        )
                    }
                }
            }
        }
        .padding(.top, 48)
    }

    private func openTutorial(_ exercise: Exercise) {
        presentTutorial(
            name: exercise.name,
            muscles: exercise.tutorialMuscles,
            slug: exercise.slug,
            hints: exercise.tutorialHints,
            hintSource: exercise.tutorialHintSource
        )
    }

    private func openTutorial(_ step: GuideStep) {
        let tips = ExerciseTips.set(for: step.title, slug: step.slug)
        presentTutorial(
            name: step.title,
            muscles: LibraryCatalog.workout(slug: step.slug)?.muscle ?? "",
            slug: step.slug,
            hints: tips.tips,
            hintSource: tips.source
        )
    }

    private func presentTutorial(
        name: String,
        muscles: String,
        slug: String,
        hints: [String],
        hintSource: String?
    ) {
        if let id = openWeightRowID {
            closeWeightRow(id)
        }
        tutorial = ExerciseTutorial(
            name: name,
            muscles: muscles,
            frames: Exercise.tutorialFrames(for: slug),
            hints: hints,
            hintSource: hintSource
        )
    }

    private func openWeightRow(_ id: String) {
        if openWeightRowID != id {
            commitWeightEdit()
        }
        withAnimation(.smooth(duration: 0.32)) {
            openWeightRowID = id
        }
    }

    private func closeWeightRow(_ id: String) {
        guard openWeightRowID == id else { return }
        commitWeightEdit()
        withAnimation(.smooth(duration: 0.32)) {
            openWeightRowID = nil
        }
    }

    /// Slide the open row shut without writing the draft.
    private func cancelWeightRow(_ id: String) {
        guard openWeightRowID == id else { return }
        editingWeightRowID = nil
        weightDraft = ""
        withAnimation(.smooth(duration: 0.32)) {
            openWeightRowID = nil
        }
    }

    private func beginWeightEdit(_ exercise: Exercise) {
        let display = weights[exercise.id] ?? exercise.displayWeight ?? ""
        weightDraft = Self.poundsText(from: display)
        editingWeightRowID = exercise.id
        openWeightRow(exercise.id)
    }

    private func commitWeightEdit() {
        guard let id = editingWeightRowID else { return }
        if let formatted = Self.formattedWeight(from: weightDraft) {
            weights[id] = formatted
        }
        editingWeightRowID = nil
        weightDraft = ""
    }

    private static func poundsText(from display: String) -> String {
        display.replacingOccurrences(of: "lbs", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func formattedWeight(from draft: String) -> String? {
        let cleaned = draft.trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned) else { return nil }
        if value.rounded() == value {
            return "\(Int(value)) lbs"
        }
        return String(format: "%.1f lbs", value)
    }

    private var credit: some View {
        Text(.init("Drawings by Everkinetic, arranged by Bryl Lim. [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .tint(.white.opacity(0.8))
    }
}

private struct MainWorkoutRow: View {
    let exercise: Exercise
    let weight: String
    let isOpen: Bool
    let isEditing: Bool
    @Binding var weightDraft: String
    let onOpen: () -> Void
    let onClose: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void
    var onSelect: (() -> Void)? = nil

    @State private var dragTranslation: CGFloat = 0

    private let buttonWidth: CGFloat = 141
    private let gap: CGFloat = 12
    private var revealWidth: CGFloat { buttonWidth + gap }

    private var offsetX: CGFloat {
        let base = isOpen ? -revealWidth : 0
        return min(0, max(-revealWidth, base + dragTranslation))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if offsetX < -4 {
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.title3)
                        .foregroundStyle(Color(red: 0.90, green: 0.90, blue: 0.92))
                        .frame(width: buttonWidth, height: 152)
                }
                .buttonStyle(.plain)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                .allowsHitTesting(isOpen)
            }

            GuideRow(
                title: exercise.name,
                metaParts: exercise.metaParts,
                slug: exercise.slug,
                weight: weight,
                isEditingWeight: isEditing,
                weightDraft: $weightDraft,
                onKeyboardDone: onClose
            )
            .offset(x: offsetX)
        }
        .frame(height: 152)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isOpen, abs(dragTranslation) < 4 else { return }
            onSelect?()
        }
        .simultaneousGesture(swipeGesture)
        .onChange(of: isOpen) { _, open in
            if !open {
                dragTranslation = 0
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .local)
            .onChanged { value in
                let translation = value.translation
                guard abs(translation.width) > abs(translation.height) * 0.65 else { return }
                dragTranslation = translation.width
            }
            .onEnded { value in
                let width = value.translation.width
                let predicted = value.predictedEndTranslation.width
                if isOpen && (width > 36 || predicted > 80) {
                    onCancel()
                } else if !isOpen && (width < -36 || predicted < -80) {
                    dragTranslation = 0
                    onOpen()
                } else {
                    withAnimation(.smooth(duration: 0.32)) {
                        dragTranslation = 0
                    }
                }
            }
    }
}

private struct GuideRow: View {
    let title: String
    let metaParts: [String]
    let slug: String
    var weight: String? = nil
    var isEditingWeight: Bool = false
    var weightDraft: Binding<String>? = nil
    var onKeyboardDone: (() -> Void)? = nil

    /// Rows keep their existing still. Workouts that only live in the library use that workout's first frame.
    private var thumbnailSlug: String {
        if UIImage(named: slug) != nil {
            return slug
        }
        return "library/\(slug)/frame-1"
    }

    var body: some View {
        HStack(spacing: 20) {
            IllustrationView(slug: thumbnailSlug, label: title)
                .frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.headline)
                MetaLine(parts: metaParts)
                    .padding(.top, 4)
                if weight != nil {
                    Text("Weight")
                        .font(.headline)
                        .padding(.top, 20)
                    weightValue
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 152)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    @ViewBuilder
    private var weightValue: some View {
        if isEditingWeight, let weightDraft {
            WeightField(
                draft: weightDraft,
                onDone: { onKeyboardDone?() }
            )
        } else if let weight {
            Text(weight)
        }
    }
}

private struct WeightField: View {
    @Binding var draft: String
    let onDone: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        TextField("lbs", text: $draft)
            .keyboardType(.decimalPad)
            .textFieldStyle(.plain)
            .focused($focused)
            .labelsHidden()
            .onAppear { focused = true }
            .onChange(of: draft) { _, newValue in
                let filtered = Self.filterPounds(newValue)
                if filtered != newValue {
                    draft = filtered
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        onDone()
                    }
                }
            }
    }

    private static func filterPounds(_ raw: String) -> String {
        var result = ""
        var sawDecimal = false
        for character in raw {
            if character.isNumber {
                result.append(character)
            } else if character == ".", !sawDecimal {
                result.append(character)
                sawDecimal = true
            }
        }
        return result
    }
}

private struct MetaLine: View {
    let parts: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index > 0 {
                    Text("·")
                }
                Text(part)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

/// Pull-down at the top must not pop. Screen-edge back swipe stays on and wins
/// over row/tile presses the same way tab pans beat Home tile holds.
struct DisableRoutineInteractivePop: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.apply()
    }

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            apply()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = true
        }

        func apply() {
            guard let nav = navigationController,
                  let pop = nav.interactivePopGestureRecognizer
            else { return }

            pop.isEnabled = true
            pop.delegate = self
            // Presses must not see the touch until the edge back pan fails. If
            // that pan begins, cancel the press so a sideways edge drag is not a hold.
            pop.delaysTouchesBegan = true
            pop.cancelsTouchesInView = true
            nav.interactiveContentPopGestureRecognizer?.isEnabled = false

            linkGestures(in: view, pop: pop)
            if let navView = nav.view {
                linkGestures(in: navView, pop: pop)
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let nav = navigationController else { return false }
            return nav.viewControllers.count > 1
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard let pop = navigationController?.interactivePopGestureRecognizer,
                  gestureRecognizer === pop
            else { return false }
            // Row taps and most pans wait. The edge back pan is screen-edge only,
            // so mid-screen weight-row swipes still begin as soon as it fails.
            return otherGestureRecognizer !== pop
        }

        private func linkGestures(in root: UIView, pop: UIGestureRecognizer) {
            var stack: [UIView] = [root]
            while let view = stack.popLast() {
                for recognizer in view.gestureRecognizers ?? [] where recognizer !== pop {
                    recognizer.require(toFail: pop)
                }
                stack.append(contentsOf: view.subviews)
            }
        }
    }
}

/// Cycles the main-exercise thumbnails inside the routine hero.
/// Each drawing is the same asset as that row, fitted to one centered square.
private struct RoutineHeroCycle: View {
    let exercises: [Exercise]
    private let interval: TimeInterval = 1.6

    var body: some View {
        TimelineView(.periodic(from: .now, by: interval)) { context in
            if exercises.isEmpty {
                Color.clear
            } else {
                let index = Int(context.date.timeIntervalSinceReferenceDate / interval) % exercises.count
                let exercise = exercises[index]
                FittedThumbnail(slug: exercise.slug, label: exercise.name)
                    .id(index)
                    .transition(.identity)
                    .transaction { $0.disablesAnimations = true }
            }
        }
    }
}

/// Places a thumbnail's ink in one shared square so the hero swap does not jump.
private struct FittedThumbnail: View {
    let slug: String
    let label: String

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let fit = ThumbnailFit.fit(for: slug)
            IllustrationView(slug: slug, label: label)
                .frame(width: side, height: side)
                .scaleEffect(fit.scale, anchor: fit.anchor)
                .offset(
                    x: (0.5 - fit.anchor.x) * side,
                    y: (0.5 - fit.anchor.y) * side
                )
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ThumbnailFit {
    var width: CGFloat
    var height: CGFloat
    var centerX: CGFloat
    var centerY: CGFloat

    var anchor: UnitPoint {
        UnitPoint(x: centerX / 512, y: centerY / 512)
    }

    /// Longest ink edge lands on the same inset, and the box center stays in the middle.
    var scale: CGFloat {
        let limit: CGFloat = 512 - 48
        return min(limit / width, limit / height)
    }

    static func fit(for slug: String) -> ThumbnailFit {
        table[slug] ?? ThumbnailFit(width: 512, height: 512, centerX: 256, centerY: 256)
    }

    /// Ink box of the still thumbnail already shown on the exercise row.
    private static let table: [String: ThumbnailFit] = [
        "dumbbell-bench-press": ThumbnailFit(width: 279, height: 417, centerX: 275, centerY: 260),
        "cable-fly": ThumbnailFit(width: 313, height: 364, centerX: 240, centerY: 250),
        "standing-dumbbell-press": ThumbnailFit(width: 182, height: 477, centerX: 252, centerY: 256),
        "lateral-raise": ThumbnailFit(width: 299, height: 338, centerX: 247, centerY: 265),
        "tricep-pushdown": ThumbnailFit(width: 146, height: 442, centerX: 240, centerY: 248),
        "seated-leg-curl": ThumbnailFit(width: 213, height: 364, centerX: 254, centerY: 273),
        "leg-extension": ThumbnailFit(width: 226, height: 364, centerX: 247, centerY: 273),
        "hip-abduction-machine": ThumbnailFit(width: 342, height: 471, centerX: 235, centerY: 249),
        "hip-adduction-machine": ThumbnailFit(width: 303, height: 472, centerX: 242, centerY: 254),
        "standing-calf-raise": ThumbnailFit(width: 236, height: 437, centerX: 281, centerY: 269),
        "pallof-press": ThumbnailFit(width: 375, height: 466, centerX: 275, centerY: 244),
        "assisted-pull-up": ThumbnailFit(width: 247, height: 488, centerX: 244, centerY: 254),
        "seated-row": ThumbnailFit(width: 408, height: 274, centerX: 284, centerY: 274),
        "lat-pulldown": ThumbnailFit(width: 179, height: 433, centerX: 252, centerY: 240),
        "cable-curl": ThumbnailFit(width: 163, height: 411, centerX: 263, centerY: 275),
        "face-pull": ThumbnailFit(width: 404, height: 463, centerX: 258, centerY: 249),
        "farmer-carry": ThumbnailFit(width: 224, height: 476, centerX: 255, centerY: 255),
        "glute-bridge": ThumbnailFit(width: 391, height: 187, centerX: 240, centerY: 281),
        "bodyweight-squat": ThumbnailFit(width: 272, height: 448, centerX: 264, centerY: 254),
        "step-up": ThumbnailFit(width: 187, height: 301, centerX: 259, centerY: 276),
        "bird-dog": ThumbnailFit(width: 496, height: 220, centerX: 254, centerY: 254),
    ]
}

#Preview {
    NavigationStack {
        RoutineView(routine: WorkoutPlan.upperPush())
    }
    .environment(SessionStore())
    .environment(WashTheme())
    .preferredColorScheme(.dark)
}
