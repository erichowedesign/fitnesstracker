import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct UpperPushView: View {
    var body: some View {
        RoutineView(routine: WorkoutPlan.upperPush())
    }
}

struct RoutineView: View {
    @Environment(SessionStore.self) private var store
    @Environment(RoutineOverridesStore.self) private var routineOverrides
    @Environment(CustomRoutinesStore.self) private var customRoutines
    @Environment(RoutineOrderStore.self) private var routineOrder
    @Environment(\.glassPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    let routine: Routine
    var startsInEditMode: Bool = false
    @State private var didSave = false
    @State private var showCompleteButton = false
    @State private var showDeleteConfirm = false
    @State private var weights: [String: String] = [:]
    @State private var tutorial: ExerciseTutorial?
    @State private var isEditingRoutine = false
    @State private var didApplyStartEditing = false
    @State private var draftWarmup: [GuideStep] = []
    @State private var draftExercises: [Exercise] = []
    @State private var draftCooldown: [GuideStep] = []
    @State private var showLibraryPicker = false
    @State private var stagedLibraryWorkout: LibraryWorkout?
    @State private var pendingLibraryWorkout: LibraryWorkout?
    @State private var addTarget: RoutineEditSection = .main
    @State private var editMode: EditMode = .inactive
    @State private var editSnapshotWarmup: [GuideStep] = []
    @State private var editSnapshotExercises: [Exercise] = []
    @State private var editSnapshotCooldown: [GuideStep] = []
    @State private var editSnapshotWeights: [String: String] = [:]
    @State private var draggingEditID: String?
    /// 1-based My Routines list position while editing.
    @State private var draftListPosition = 1

    private var canDeleteRoutine: Bool {
        routine.isCustom || customRoutines.contains(routine.id)
    }

    private var shippingRoutines: [Routine] {
        WorkoutPlan.all().map(routineOverrides.resolved)
    }

    private var orderedCatalog: [Routine] {
        routineOrder.ordered(
            shipping: shippingRoutines,
            customs: customRoutines.routines(startingRotationAt: shippingRoutines.count + 1)
        )
    }

    private var currentListNumber: Int {
        (orderedCatalog.firstIndex { $0.id == routine.id } ?? 0) + 1
    }

    private var activeRoutine: Routine {
        routine.withSections(
            warmup: draftWarmup,
            exercises: draftExercises,
            cooldown: draftCooldown
        )
    }

    var body: some View {
        routineScroll
            .scrollDismissesKeyboard(.immediately)
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectHidden(true, for: .vertical)
            .glassInk()
            .background { routineWashBackground }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { completeInset }
            .navigationTitle(isEditingRoutine ? "" : "Routine \(currentListNumber)")
            .toolbarTitleDisplayMode(.inline)
            // Custom glass chrome — system back / plain Edit ignore Clear–Dark.
            .navigationBarBackButtonHidden(true)
            .toolbar { editToolbar }
            .preferredColorScheme(palette.colorScheme)
            .animation(.smooth(duration: 0.3), value: palette.mode)
            .environment(\.editMode, $editMode)
            .alert("Workout saved", isPresented: $didSave) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(routine.name) is stored on this iPhone.")
            }
            .alert("Delete routine?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive, action: deleteCustomRoutine)
            } message: {
                Text("“\(routine.name)” will be removed from My Routines. This can’t be undone.")
            }
            .background { DisableRoutineInteractivePop(allowsEdgeBack: !isEditingRoutine) }
            .navigationDestination(item: $tutorial) { item in
                ExerciseTutorialView(
                    exerciseName: item.name,
                    muscles: item.muscles,
                    grade: routine.washGrade,
                    frames: item.frames,
                    hints: item.hints,
                    hintSource: item.hintSource,
                    favoriteSlug: item.favoriteSlug,
                    sectionTitle: item.sectionTitle,
                    initialDose: item.dose,
                    onDoseChange: applyDoseChange
                )
            }
            .modifier(RoutineEditSheets(
                showLibraryPicker: $showLibraryPicker,
                stagedLibraryWorkout: $stagedLibraryWorkout,
                pendingLibraryWorkout: $pendingLibraryWorkout,
                onAdd: addLibraryExercise
            ))
            .onAppear {
                loadDraft()
                applyStartEditingIfNeeded()
            }
    }

    private var routineScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(routine.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text(routine.focus)
                    .font(.body)
                    .padding(.top, 8)

                if !isEditingRoutine {
                    RoutineHeroCycle(frames: heroCycleFrames)
                        .frame(maxWidth: .infinity)
                        .frame(height: 370)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .padding(.top, 32)

                    glanceCard
                        .padding(.top, 16)
                }

                if isEditingRoutine {
                    if routine.includesWarmup {
                        editableGuideSection(
                            title: "Warm-up",
                            steps: $draftWarmup,
                            section: .warmup
                        )
                    }
                    if routine.includesMain {
                        editableMainSection
                    }
                    if routine.includesCooldown {
                        editableGuideSection(
                            title: "Cool Down",
                            steps: $draftCooldown,
                            section: .cooldown
                        )
                    }
                    if canDeleteRoutine {
                        deleteRoutineButton
                            .padding(.top, 48)
                    }
                } else {
                    // 48pt below hero block (summary description removed).
                    if routine.includesWarmup {
                        section("Warm-up", steps: draftWarmup, revealsCompleteButton: true)
                    }
                    if routine.includesMain {
                        mainWorkoutSection
                    }
                    if routine.includesCooldown {
                        section("Cool Down", steps: draftCooldown)
                    }
                }

            }
            .padding(.horizontal, 16)
            .padding(.top, 34)
            .padding(.bottom, 88)
        }
    }

    private var deleteRoutineButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            Label("Delete", systemImage: "trash")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            Capsule().fill(Color(red: 1, green: 0.14, blue: 0.12).opacity(0.58))
        }
        .foundationGlass(interactive: true, in: Capsule())
        .accessibilityLabel("Delete routine")
    }

    private var routineWashBackground: some View {
        ZStack {
            Color.black
            WashBackground(grade: routine.washGrade)
        }
        .ignoresSafeArea()
    }

    /// Main-workout images when present; otherwise warmup/cooldown stills.
    private var heroCycleFrames: [RoutineHeroFrame] {
        if !draftExercises.isEmpty {
            return draftExercises.map {
                RoutineHeroFrame(id: $0.id, slug: $0.slug, name: $0.name)
            }
        }
        let guides = draftWarmup + draftCooldown
        return guides.map {
            RoutineHeroFrame(id: $0.id, slug: $0.slug, name: $0.title)
        }
    }

    private var completeInset: some View {
        ZStack {
            if showCompleteButton, !isEditingRoutine {
                completeWorkoutButton
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.4), value: showCompleteButton)
        .animation(.smooth(duration: 0.28), value: isEditingRoutine)
    }

    @ToolbarContentBuilder
    private var editToolbar: some ToolbarContent {
        if isEditingRoutine {
            ToolbarItem(placement: .topBarLeading) {
                GlassChromeIconButton(
                    systemName: "xmark",
                    accessibilityLabel: "Cancel editing",
                    action: cancelRoutineEditing
                )
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .principal) {
                listPositionMenu
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                GlassChromeIconButton(
                    systemName: "checkmark",
                    accessibilityLabel: "Save edits",
                    action: commitRoutineEditing
                )
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) {
                GlassChromeIconButton(
                    systemName: "chevron.backward",
                    accessibilityLabel: "Back",
                    action: { dismiss() }
                )
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                GlassChromeLabelButton(title: "Edit", action: beginRoutineEditing)
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    private var listPositionMenu: some View {
        Menu {
            ForEach(1...max(orderedCatalog.count, 1), id: \.self) { position in
                Button {
                    draftListPosition = position
                } label: {
                    if position == draftListPosition {
                        Label("Routine \(position)", systemImage: "checkmark")
                    } else {
                        Text("Routine \(position)")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("Routine \(draftListPosition)")
                    .font(.headline)
                    .glassInk()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .glassInk(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foundationGlass(interactive: true, in: Capsule())
        .accessibilityLabel("Routine list position")
        .accessibilityValue("\(draftListPosition)")
    }

    private func loadDraft() {
        if routine.isCustom || customRoutines.contains(routine.id) {
            draftWarmup = routine.includesWarmup ? routine.warmup : []
            draftExercises = routine.includesMain ? routine.exercises : []
            draftCooldown = routine.includesCooldown ? routine.cooldown : []
        } else {
            draftWarmup = routineOverrides.warmup(for: routine.id, fallback: routine.warmup)
            draftExercises = routineOverrides.exercises(for: routine.id, fallback: routine.exercises)
            draftCooldown = routineOverrides.cooldown(for: routine.id, fallback: routine.cooldown)
        }
        for exercise in draftExercises {
            guard weights[exercise.id] == nil, let seed = exercise.displayWeight else { continue }
            weights[exercise.id] = seed
        }
    }

    private func applyStartEditingIfNeeded() {
        guard startsInEditMode, !didApplyStartEditing else { return }
        didApplyStartEditing = true
        beginRoutineEditing()
    }

    private func addLibraryExercise(_ workout: LibraryWorkout, sets: Int, reps: Int, weight: String?) {
        switch addTarget {
        case .warmup:
            draftWarmup.append(GuideStep.fromLibrary(workout, sets: sets, reps: reps, weight: weight))
        case .main:
            let exercise = Exercise.fromLibrary(workout, sets: sets, reps: reps, weight: weight)
            draftExercises.append(exercise)
            if let weight, !weight.trimmingCharacters(in: .whitespaces).isEmpty {
                weights[exercise.id] = exercise.displayWeight ?? weight
            }
        case .cooldown:
            draftCooldown.append(GuideStep.fromLibrary(workout, sets: sets, reps: reps, weight: weight))
        }
        pendingLibraryWorkout = nil
    }

    private func beginAdding(to section: RoutineEditSection) {
        addTarget = section
        showLibraryPicker = true
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
                    glanceNumber(activeRoutine.exerciseCountLabel)
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
        .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(draftExercises.count) exercises, \(routine.minutes) minutes, difficulty \(routine.difficulty) of five")
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
            store.complete(activeRoutine, weights: weights)
            didSave = true
        } label: {
            Text("Complete Workout")
                .font(.title3.weight(.semibold))
                .glassInk()
                .frame(maxWidth: .infinity)
                .frame(height: 64)
        }
        .buttonStyle(.plain)
        // Same glass family as the Home floating tab bar.
        .foundationGlass(interactive: true, in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityAddTraits(.isButton)
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
                            .onTapGesture { openTutorial(step, sectionTitle: title) }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint("Opens the tutorial to adjust weight, reps, and sets")
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
                    ForEach(draftExercises) { exercise in
                        GuideRow(
                            title: exercise.name,
                            metaParts: exercise.metaParts,
                            slug: exercise.slug,
                            weight: weights[exercise.id] ?? exercise.displayWeight ?? "—"
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { openTutorial(exercise) }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Opens the tutorial to adjust weight, reps, and sets")
                    }
                }
            }
        }
        .padding(.top, 48)
    }

    private var editableMainSection: some View {
        editableSectionChrome(title: "Main Workout", section: .main) {
            editableReorderList(items: $draftExercises) { exercise in
                if let index = draftExercises.firstIndex(where: { $0.id == exercise.id }) {
                    deleteExercises(at: IndexSet(integer: index))
                }
            } content: { exercise in
                editableRowContent(
                    title: exercise.name,
                    metaParts: exercise.metaParts,
                    slug: exercise.slug
                )
            }
        }
    }

    private func editableGuideSection(
        title: String,
        steps: Binding<[GuideStep]>,
        section: RoutineEditSection
    ) -> some View {
        editableSectionChrome(title: title, section: section) {
            editableReorderList(items: steps) { step in
                steps.wrappedValue.removeAll { $0.id == step.id }
            } content: { step in
                editableRowContent(title: step.title, metaParts: step.metaParts, slug: step.slug)
            }
        }
    }

    private func editableSectionChrome<Content: View>(
        title: String,
        section: RoutineEditSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer(minLength: 0)
                Button {
                    beginAdding(to: section)
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.body.weight(.semibold))
                        .glassInk()
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foundationGlass(interactive: true, in: Capsule())
                .accessibilityLabel("Add to \(title)")
            }
            content()
        }
        .padding(.top, 24)
    }

    /// Custom edit rows: small liquid-glass minus + drag-handle; tiles use Clear/Dark/Light `foundationGlass` (not a flat dim fill).
    private func editableReorderList<Item: Identifiable>(
        items: Binding<[Item]>,
        onDelete: @escaping (Item) -> Void,
        @ViewBuilder content: @escaping (Item) -> some View
    ) -> some View where Item.ID == String {
        let count = items.wrappedValue.count
        // No GlassEffectContainer here — keep ± / drag circles from melting into the row tile.
        return VStack(spacing: 8) {
            ForEach(items.wrappedValue) { item in
                HStack(spacing: 10) {
                    GlassChromeIconButton(
                        systemName: "minus",
                        accessibilityLabel: "Remove",
                        ink: .white,
                        tint: Color(red: 1, green: 0.14, blue: 0.12),
                        size: 32
                    ) {
                        onDelete(item)
                    }

                    content(item)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    GlassChromeSymbolCircle(
                        systemName: "line.3.horizontal",
                        accessibilityLabel: "Reorder",
                        size: 32
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .foundationGlass(
                    interactive: true,
                    in: RoundedRectangle(cornerRadius: 34, style: .continuous)
                )
                .onDrag {
                    draggingEditID = item.id
                    return NSItemProvider(object: item.id as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: EditReorderDropDelegate(
                        itemID: item.id,
                        items: items,
                        draggingID: $draggingEditID
                    )
                )
            }
        }
        .frame(minHeight: max(CGFloat(count) * 104, 120), alignment: .top)
        .preferredColorScheme(palette.colorScheme)
    }

    private func editableRowContent(title: String, metaParts: [String], slug: String) -> some View {
        HStack(spacing: 16) {
            IllustrationView(slug: editThumbSlug(slug), label: title)
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .glassInk()
                MetaLine(parts: metaParts)
            }
            Spacer(minLength: 0)
        }
    }

    private func beginRoutineEditing() {
        editSnapshotWarmup = draftWarmup
        editSnapshotExercises = draftExercises
        editSnapshotCooldown = draftCooldown
        editSnapshotWeights = weights
        draftListPosition = currentListNumber
        withAnimation(.smooth(duration: 0.28)) {
            isEditingRoutine = true
            editMode = .active
            showCompleteButton = false
        }
    }

    private func commitRoutineEditing() {
        persistDraft()
        if draftListPosition != currentListNumber {
            routineOrder.move(
                id: routine.id,
                toPosition: draftListPosition,
                inOrderedCatalog: orderedCatalog
            )
        }
        withAnimation(.smooth(duration: 0.28)) {
            isEditingRoutine = false
            editMode = .inactive
        }
    }

    private func cancelRoutineEditing() {
        draftWarmup = editSnapshotWarmup
        draftExercises = editSnapshotExercises
        draftCooldown = editSnapshotCooldown
        weights = editSnapshotWeights
        draftListPosition = currentListNumber
        showLibraryPicker = false
        stagedLibraryWorkout = nil
        pendingLibraryWorkout = nil
        withAnimation(.smooth(duration: 0.28)) {
            isEditingRoutine = false
            editMode = .inactive
        }
    }

    private func persistDraft() {
        if routine.isCustom || customRoutines.contains(routine.id) {
            customRoutines.save(
                warmup: draftWarmup,
                exercises: draftExercises,
                cooldown: draftCooldown,
                for: routine.id
            )
        } else {
            routineOverrides.save(
                warmup: draftWarmup,
                exercises: draftExercises,
                cooldown: draftCooldown,
                for: routine.id
            )
        }
    }

    private func deleteCustomRoutine() {
        guard canDeleteRoutine else { return }
        customRoutines.delete(id: routine.id)
        routineOrder.remove(id: routine.id)
        dismiss()
    }

    private func deleteExercises(at offsets: IndexSet) {
        let removed = offsets.map { draftExercises[$0].id }
        draftExercises.remove(atOffsets: offsets)
        for id in removed {
            weights.removeValue(forKey: id)
        }
    }

    private func editThumbSlug(_ slug: String) -> String {
        if UIImage(named: slug) != nil { return slug }
        return "library/\(slug)/frame-1"
    }

    private func openTutorial(_ exercise: Exercise) {
        let weightLbs = Exercise.poundsValue(from: weights[exercise.id] ?? exercise.displayWeight)
        tutorial = ExerciseTutorial(
            name: exercise.name,
            muscles: exercise.tutorialMuscles,
            frames: exercise.tutorialFrames,
            hints: exercise.tutorialHints,
            hintSource: exercise.tutorialHintSource,
            favoriteSlug: exercise.slug,
            sectionTitle: "Main Workout",
            dose: RoutineDoseFields(
                itemID: exercise.id,
                section: .main,
                weightLbs: weightLbs,
                reps: exercise.doseReps,
                sets: exercise.sets
            )
        )
    }

    private func openTutorial(_ step: GuideStep, sectionTitle: String) {
        let tips = ExerciseTips.set(for: step.title, slug: step.slug)
        let section: RoutineDoseFields.Section = sectionTitle == "Cool Down" ? .cooldown : .warmup
        tutorial = ExerciseTutorial(
            name: step.title,
            muscles: LibraryCatalog.workout(slug: step.slug)?.muscle ?? "",
            frames: Exercise.tutorialFrames(for: step.slug),
            hints: tips.tips,
            hintSource: tips.source,
            favoriteSlug: step.slug,
            sectionTitle: sectionTitle,
            dose: RoutineDoseFields(
                itemID: step.id,
                section: section,
                weightLbs: step.doseWeightLbs,
                reps: step.doseReps,
                sets: step.doseSets
            )
        )
    }

    private func applyDoseChange(_ dose: RoutineDoseFields) {
        switch dose.section {
        case .main:
            guard let index = draftExercises.firstIndex(where: { $0.id == dose.itemID }) else { return }
            let updated = draftExercises[index].withDose(
                reps: dose.reps,
                sets: dose.sets,
                weightLbs: dose.weightLbs
            )
            draftExercises[index] = updated
            if dose.weightLbs > 0 {
                weights[dose.itemID] = updated.displayWeight ?? "\(dose.weightLbs) lbs"
            } else {
                weights.removeValue(forKey: dose.itemID)
            }
        case .warmup:
            guard let index = draftWarmup.firstIndex(where: { $0.id == dose.itemID }) else { return }
            draftWarmup[index] = draftWarmup[index].withDose(
                reps: dose.reps,
                sets: dose.sets,
                weightLbs: dose.weightLbs
            )
        case .cooldown:
            guard let index = draftCooldown.firstIndex(where: { $0.id == dose.itemID }) else { return }
            draftCooldown[index] = draftCooldown[index].withDose(
                reps: dose.reps,
                sets: dose.sets,
                weightLbs: dose.weightLbs
            )
        }
        persistDraft()
    }
}

private enum RoutineEditSection {
    case warmup, main, cooldown
}

/// Reorders edit-mode rows while a glass drag handle is dragged across neighbors.
private struct EditReorderDropDelegate<Item: Identifiable>: DropDelegate where Item.ID == String {
    let itemID: String
    @Binding var items: [Item]
    @Binding var draggingID: String?

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != itemID,
              let from = items.firstIndex(where: { $0.id == draggingID }),
              let to = items.firstIndex(where: { $0.id == itemID })
        else { return }
        withAnimation(.snappy(duration: 0.2)) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

private struct RoutineEditSheets: ViewModifier {
    @Binding var showLibraryPicker: Bool
    @Binding var stagedLibraryWorkout: LibraryWorkout?
    @Binding var pendingLibraryWorkout: LibraryWorkout?
    var onAdd: (_ workout: LibraryWorkout, _ sets: Int, _ reps: Int, _ weight: String?) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showLibraryPicker, onDismiss: presentDoseSheetIfNeeded) {
                LibraryExercisePicker { workout in
                    stagedLibraryWorkout = workout
                    showLibraryPicker = false
                }
            }
            .sheet(item: $pendingLibraryWorkout) { workout in
                AddLibraryExerciseSheet(workout: workout) { sets, reps, weight in
                    onAdd(workout, sets, reps, weight)
                }
            }
    }

    private func presentDoseSheetIfNeeded() {
        guard let stagedLibraryWorkout else { return }
        pendingLibraryWorkout = stagedLibraryWorkout
        self.stagedLibraryWorkout = nil
    }
}

private struct LibraryExercisePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.glassPalette) private var palette
    var onPick: (LibraryWorkout) -> Void
    @State private var query = ""
    @State private var filter: LibraryListFilter = .all
    @State private var favoritesOnly = false

    var body: some View {
        NavigationStack {
            LibraryBrowser(
                query: $query,
                filter: $filter,
                favoritesOnly: $favoritesOnly,
                title: "Library",
                showsCancel: true,
                bottomInset: 24,
                onCancel: { dismiss() },
                onSelect: onPick
            )
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Library")
                        .opacity(0)
                        .accessibilityHidden(true)
                }
            }
        }
        .preferredColorScheme(palette.colorScheme)
        .presentationBackground {
            ZStack {
                Color.black
                WashBackground(grade: .grayscale)
            }
            .ignoresSafeArea()
        }
    }
}

private struct AddLibraryExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.glassPalette) private var palette
    let workout: LibraryWorkout
    var onAdd: (_ sets: Int, _ reps: Int, _ weight: String?) -> Void

    @State private var setsText = "3"
    @State private var repsText = "10"
    @State private var weightText = ""

    private var setsValue: Int? { Int(setsText.trimmingCharacters(in: .whitespaces)) }
    private var repsValue: Int? { Int(repsText.trimmingCharacters(in: .whitespaces)) }
    private var canAdd: Bool {
        guard let setsValue, let repsValue else { return false }
        return setsValue > 0 && repsValue > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        IllustrationView(slug: workout.frames[0], label: workout.name)
                            .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name)
                                .font(.headline)
                                .glassInk()
                            Text("\(workout.equipment) · \(workout.muscle)")
                                .font(.subheadline)
                                .glassInk(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    LabeledContent("Reps") {
                        TextField("Reps", text: $repsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Sets") {
                        TextField("Sets", text: $setsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Weight") {
                        TextField("Optional", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .glassInk()
            .navigationTitle("Define Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(palette.colorScheme)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GlassChromeLabelButton(title: "Cancel", action: { dismiss() })
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) {
                    GlassChromeLabelButton(title: "Add") {
                        guard let setsValue, let repsValue else { return }
                        let trimmed = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
                        onAdd(setsValue, repsValue, trimmed.isEmpty ? nil : trimmed)
                    }
                    .opacity(canAdd ? 1 : 0.45)
                    .allowsHitTesting(canAdd)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .presentationBackground {
            ZStack {
                Color.black
                WashBackground(grade: .grayscale)
            }
            .ignoresSafeArea()
        }
    }
}

private struct GuideRow: View {
    let title: String
    let metaParts: [String]
    let slug: String
    var weight: String? = nil

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
                if let weight {
                    Text("Weight")
                        .font(.headline)
                        .padding(.top, 20)
                    Text(weight)
                        .font(.subheadline)
                        .glassInk(.secondary)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 152)
        .foundationGlass(interactive: false, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
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
        .glassInk(.secondary)
        .lineLimit(1)
    }
}

/// Pull-down at the top must not pop. Screen-edge back swipe stays on and wins
/// over row/tile presses the same way tab pans beat Home tile holds.
/// Pass `allowsEdgeBack: false` while editing so X/checkmark own exit (no discard via swipe).
struct DisableRoutineInteractivePop: UIViewControllerRepresentable {
    var allowsEdgeBack: Bool = true

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.allowsEdgeBack = allowsEdgeBack
        controller.apply()
    }

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        var allowsEdgeBack = true

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
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = true
        }

        func apply() {
            guard let nav = navigationController,
                  let pop = nav.interactivePopGestureRecognizer
            else { return }

            nav.interactiveContentPopGestureRecognizer?.isEnabled = false

            guard allowsEdgeBack else {
                pop.isEnabled = false
                return
            }

            pop.isEnabled = true
            pop.delegate = self
            // Presses must not see the touch until the edge back pan fails. If
            // that pan begins, cancel the press so a sideways edge drag is not a hold.
            pop.delaysTouchesBegan = true
            pop.cancelsTouchesInView = true

            linkGestures(in: view, pop: pop)
            if let navView = nav.view {
                linkGestures(in: navView, pop: pop)
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard allowsEdgeBack, let nav = navigationController else { return false }
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

private struct RoutineHeroFrame: Identifiable {
    var id: String
    var slug: String
    var name: String
}

/// Cycles workout stills inside the routine hero (main first; else guide steps).
private struct RoutineHeroCycle: View {
    let frames: [RoutineHeroFrame]
    private let interval: TimeInterval = 1.6

    var body: some View {
        TimelineView(.periodic(from: .now, by: interval)) { context in
            if frames.isEmpty {
                Color.clear
            } else {
                let index = Int(context.date.timeIntervalSinceReferenceDate / interval) % frames.count
                let frame = frames[index]
                FittedThumbnail(slug: frame.slug, label: frame.name)
                    .id(frame.id)
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
    .environment(RoutineOverridesStore())
    .environment(CustomRoutinesStore())
    .environment(RoutineOrderStore())
    .environment(FavoritesStore())
    .environment(WashTheme())
    .preferredColorScheme(.dark)
}
