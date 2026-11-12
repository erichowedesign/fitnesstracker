import SwiftUI

struct UpperPushView: View {
    var body: some View {
        RoutineView(routine: WorkoutPlan.upperPush())
    }
}

struct RoutineView: View {
    @Environment(SessionStore.self) private var store
    let routine: Routine
    var hero: Namespace.ID? = nil
    @State private var didSave = false
    @State private var showCompleteButton = false
    @State private var openWeightRowID: String?
    @State private var editingWeightRowID: String?
    @State private var weightDraft = ""
    @State private var weights: [String: String] = [:]

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(routine.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .homeHeroMatch("title-\(routine.id)", in: hero, isSource: false)
                    Text(routine.focus)
                        .font(.body)
                        .homeHeroMatch("focus-\(routine.id)", in: hero, isSource: false)
                        .padding(.top, 8)

                    IllustrationView(slug: routine.heroSlug, label: routine.name)
                        .frame(maxWidth: .infinity)
                        .frame(height: 370)
                        .homeHeroMatch("hero-art-\(routine.id)", in: hero, isSource: false)
                        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
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
        .toolbarBackground(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            topStatusScrim
        }
        .safeAreaInset(edge: .bottom) {
            ZStack {
                if showCompleteButton {
                    completeWorkoutButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.4), value: showCompleteButton)
        }
        .navigationTitle("Routine \(routine.id)")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if hero != nil {
                ToolbarItem(placement: .principal) {
                    Text("Routine \(routine.id)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .homeHeroMatch("eyebrow-\(routine.id)", in: hero, isSource: false)
                }
            }
        }
        .alert("Workout saved", isPresented: $didSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(routine.name) is stored on this iPhone.")
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
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
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

    private var topStatusScrim: some View {
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

    private var completeWorkoutButton: some View {
        Button {
            store.complete(routine)
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
                            onCommit: commitWeightEdit
                        )
                    }
                }
            }
        }
        .padding(.top, 48)
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
    let onCommit: () -> Void

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
                .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                .allowsHitTesting(isOpen)
            }

            GuideRow(
                title: exercise.name,
                metaParts: exercise.metaParts,
                slug: exercise.slug,
                weight: weight,
                isEditingWeight: isEditing,
                weightDraft: $weightDraft,
                onCommit: onCommit,
                onKeyboardDone: onClose
            )
            .offset(x: offsetX)
        }
        .frame(height: 152)
        .clipped()
        .contentShape(Rectangle())
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
                dragTranslation = 0
                if isOpen {
                    if width > 36 || predicted > 80 {
                        onClose()
                    }
                } else if width < -36 || predicted < -80 {
                    onOpen()
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
    var onCommit: (() -> Void)? = nil
    var onKeyboardDone: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 20) {
            IllustrationView(slug: slug, label: title)
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
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    @ViewBuilder
    private var weightValue: some View {
        if isEditingWeight, let weightDraft {
            WeightField(
                draft: weightDraft,
                onCommit: { onCommit?() },
                onDone: { onKeyboardDone?() }
            )
        } else if let weight {
            Text(weight)
        }
    }
}

private struct WeightField: View {
    @Binding var draft: String
    let onCommit: () -> Void
    let onDone: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        TextField("lbs", text: $draft)
            .keyboardType(.decimalPad)
            .textFieldStyle(.plain)
            .focused($focused)
            .labelsHidden()
            .onAppear { focused = true }
            .onChange(of: focused) { _, isFocused in
                if !isFocused {
                    onCommit()
                }
            }
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

#Preview {
    NavigationStack {
        RoutineView(routine: WorkoutPlan.upperPush())
    }
    .environment(SessionStore())
    .environment(WashTheme())
    .preferredColorScheme(.dark)
}
