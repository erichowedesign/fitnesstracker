import Foundation

struct WorkoutPlanFile: Codable {
    let schemaVersion: Int
    let planName: String
    let routines: [SeedRoutine]
}

struct SeedRoutine: Codable, Identifiable {
    let id: String
    let name: String
    let focus: String
    let warmup: RoutineBlock
    let cooldown: RoutineBlock
    let exercises: [SeedExercise]
}

struct RoutineBlock: Codable {
    let targetMinutes: Int
    let instructions: String
}

struct SeedExercise: Codable {
    let hevyTemplateId: String
    let name: String
    let equipment: String
    let sets: Int
    let targetReps: Int?
    let targetDurationSeconds: Int?
    let restSeconds: Int
    let notes: String
    let videoUrl: String?
}

struct Routine: Identifiable, Hashable {
    let id: String
    let name: String
    let focus: String
    let summary: String
    let heroSlug: String
    let rotationIndex: Int
    let warmup: [GuideStep]
    let exercises: [Exercise]
    let cooldown: [GuideStep]
    let minutes: Int
    let difficulty: Int
    /// When false, the section is omitted from browse + edit chrome.
    var includesWarmup: Bool = true
    var includesMain: Bool = true
    var includesCooldown: Bool = true
    var isCustom: Bool = false
    /// Wash / tile grade. Defaults from shipping map / custom library; editable via theme picker.
    var washGrade: WashGrade = .thermal

    var exerciseCountLabel: String {
        String(format: "%02d", exercises.count)
    }

    var workoutsLine: String {
        "\(exerciseCountLabel) workouts / \(minutes) minutes"
    }

    /// First workout image across Warm-up → Main → Cool Down.
    var thumbnailSlug: String {
        if let step = warmup.first { return step.slug }
        if let exercise = exercises.first { return exercise.slug }
        if let step = cooldown.first { return step.slug }
        return heroSlug
    }

    func withExercises(_ exercises: [Exercise]) -> Routine {
        withSections(exercises: exercises)
    }

    func withSections(
        warmup: [GuideStep]? = nil,
        exercises: [Exercise]? = nil,
        cooldown: [GuideStep]? = nil
    ) -> Routine {
        let nextWarmup = warmup ?? self.warmup
        let nextExercises = exercises ?? self.exercises
        let nextCooldown = cooldown ?? self.cooldown
        let thumb: String = {
            if let step = nextWarmup.first { return step.slug }
            if let exercise = nextExercises.first { return exercise.slug }
            if let step = nextCooldown.first { return step.slug }
            return heroSlug
        }()
        return Routine(
            id: id,
            name: name,
            focus: focus,
            summary: summary,
            heroSlug: thumb,
            rotationIndex: rotationIndex,
            warmup: nextWarmup,
            exercises: nextExercises,
            cooldown: nextCooldown,
            minutes: minutes,
            difficulty: difficulty,
            includesWarmup: includesWarmup,
            includesMain: includesMain,
            includesCooldown: includesCooldown,
            isCustom: isCustom,
            washGrade: washGrade
        )
    }

    static func == (lhs: Routine, rhs: Routine) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Exercise: Identifiable {
    let id: String
    let hevyTemplateId: String
    let name: String
    let equipment: String
    let sets: Int
    let targetReps: Int?
    let targetDurationSeconds: Int?
    let restSeconds: Int
    let notes: String
    let tracksAssistance: Bool
    let slug: String
    let displayWeight: String?

    var tutorialFrames: [String] {
        Self.tutorialFrames(for: slug)
    }

    /// Upper Push keeps the frame set already aligned for its tutorials.
    /// Every other workout uses that workout's three library frames.
    static func tutorialFrames(for slug: String) -> [String] {
        if alignedTutorialSlugs.contains(slug) {
            return (1...3).map { "\(slug)-frame-\($0)" }
        }
        return (1...3).map { "library/\(slug)/frame-\($0)" }
    }

    private static let alignedTutorialSlugs: Set<String> = [
        "cable-fly",
        "dumbbell-bench-press",
        "lateral-raise",
        "standing-dumbbell-press",
        "tricep-pushdown",
    ]

    var tutorialMuscles: String {
        LibraryCatalog.workout(slug: slug)?.muscle ?? equipment.capitalized
    }

    var tutorialHints: [String] {
        ExerciseTips.set(for: name).tips
    }

    var tutorialHintSource: String? {
        ExerciseTips.set(for: name).source
    }

    var metaParts: [String] {
        let work: String
        if let targetDurationSeconds, targetReps == nil {
            work = "\(targetDurationSeconds) sec"
        } else if let targetReps {
            work = "\(targetReps) reps"
        } else {
            work = "—"
        }
        return [work, "\(sets) sets", Self.restLabel(restSeconds)]
    }

    var doseWeightLbs: Int {
        Self.poundsValue(from: displayWeight)
    }

    var doseReps: Int {
        max(targetReps ?? 10, 1)
    }

    func withDose(reps: Int, sets: Int, weightLbs: Int) -> Exercise {
        let display: String? = weightLbs > 0 ? "\(weightLbs) lbs" : nil
        return Exercise(
            id: id,
            hevyTemplateId: hevyTemplateId,
            name: name,
            equipment: equipment,
            sets: max(sets, 1),
            targetReps: max(reps, 1),
            targetDurationSeconds: nil,
            restSeconds: restSeconds,
            notes: notes,
            tracksAssistance: tracksAssistance,
            slug: slug,
            displayWeight: display
        )
    }

    static func poundsValue(from display: String?) -> Int {
        guard let display else { return 0 }
        let cleaned = display
            .replacingOccurrences(of: "lbs", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Int(cleaned) { return max(value, 0) }
        if let value = Double(cleaned) { return max(Int(value.rounded()), 0) }
        return 0
    }

    static func fromLibrary(
        _ workout: LibraryWorkout,
        sets: Int,
        reps: Int,
        weight: String?,
        restSeconds: Int = 90
    ) -> Exercise {
        let trimmedWeight = weight?.trimmingCharacters(in: .whitespacesAndNewlines)
        let display: String? = {
            guard let trimmedWeight, !trimmedWeight.isEmpty else { return nil }
            if trimmedWeight.localizedCaseInsensitiveContains("lbs") { return trimmedWeight }
            return "\(trimmedWeight) lbs"
        }()
        return Exercise(
            id: "\(workout.slug)-\(UUID().uuidString.prefix(8))",
            hevyTemplateId: workout.slug,
            name: workout.name,
            equipment: workout.equipment,
            sets: max(sets, 1),
            targetReps: max(reps, 1),
            targetDurationSeconds: nil,
            restSeconds: restSeconds,
            notes: "",
            tracksAssistance: workout.name.range(of: "assisted", options: .caseInsensitive) != nil,
            slug: workout.slug,
            displayWeight: display
        )
    }

    private static func restLabel(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", remainder)) rest"
        }
        return "\(seconds) sec rest"
    }
}

struct GuideStep: Identifiable, Equatable {
    let id: String
    let title: String
    let metaParts: [String]
    let slug: String

    init(id: String = UUID().uuidString, title: String, metaParts: [String], slug: String) {
        self.id = id
        self.title = title
        self.metaParts = metaParts
        self.slug = slug
    }

    static func fromLibrary(_ workout: LibraryWorkout, sets: Int, reps: Int, weight: String?) -> GuideStep {
        GuideStep(
            id: "\(workout.slug)-\(UUID().uuidString.prefix(8))",
            title: workout.name,
            metaParts: doseMetaParts(reps: reps, sets: sets, weightLbs: Exercise.poundsValue(from: weight)),
            slug: workout.slug
        )
    }

    var doseReps: Int {
        Self.firstInt(in: metaParts.first(where: { $0.localizedCaseInsensitiveContains("rep") })) ?? 10
    }

    var doseSets: Int {
        Self.firstInt(in: metaParts.first(where: { $0.localizedCaseInsensitiveContains("set") })) ?? 2
    }

    var doseWeightLbs: Int {
        if let part = metaParts.first(where: { $0.localizedCaseInsensitiveContains("lbs") }) {
            return Exercise.poundsValue(from: part)
        }
        return 0
    }

    func withDose(reps: Int, sets: Int, weightLbs: Int) -> GuideStep {
        GuideStep(
            id: id,
            title: title,
            metaParts: Self.doseMetaParts(reps: reps, sets: sets, weightLbs: weightLbs),
            slug: slug
        )
    }

    private static func doseMetaParts(reps: Int, sets: Int, weightLbs: Int) -> [String] {
        var parts = ["\(max(reps, 1)) reps", "\(max(sets, 1)) sets"]
        if weightLbs > 0 {
            parts.append("\(weightLbs) lbs")
        }
        return parts
    }

    private static func firstInt(in text: String?) -> Int? {
        guard let text else { return nil }
        let digits = text.split(whereSeparator: { !$0.isNumber }).first.map(String.init)
        guard let digits, let value = Int(digits) else { return nil }
        return value
    }
}

enum WorkoutPlan {
    static func load() -> WorkoutPlanFile {
        guard let url = Bundle.main.url(forResource: "workouts", withExtension: "json") else {
            fatalError("workouts.json is missing from the app bundle.")
        }
        do {
            return try JSONDecoder().decode(WorkoutPlanFile.self, from: Data(contentsOf: url))
        } catch {
            fatalError("Could not read workouts.json: \(error)")
        }
    }

    static func all() -> [Routine] {
        load().routines.enumerated().map { index, seed in
            makeRoutine(seed, rotationIndex: index + 1)
        }
    }

    static func upperPush() -> Routine {
        guard let routine = all().first(where: { $0.id == "A" }) else {
            fatalError("Upper Push (routine A) is missing from workouts.json.")
        }
        return routine
    }

    private static func makeRoutine(_ seed: SeedRoutine, rotationIndex: Int) -> Routine {
        let warmup = guideSteps(routineId: seed.id, phase: .warmup, instructions: seed.warmup.instructions)
        let exercises = seed.exercises.map { exercise in
            Exercise(
                id: "\(seed.id)-\(exercise.hevyTemplateId)",
                hevyTemplateId: exercise.hevyTemplateId,
                name: exercise.name,
                equipment: exercise.equipment,
                sets: exercise.sets,
                targetReps: exercise.targetReps,
                targetDurationSeconds: exercise.targetDurationSeconds,
                restSeconds: exercise.restSeconds,
                notes: exercise.notes,
                tracksAssistance: exercise.equipment.lowercased().contains("assisted")
                    || exercise.name.range(of: "assisted pull-?up", options: .regularExpression) != nil,
                slug: illustrationSlug(for: exercise.name),
                displayWeight: displayWeight(for: exercise.name)
            )
        }
        let cooldown = guideSteps(routineId: seed.id, phase: .cooldown, instructions: seed.cooldown.instructions)
        let thumb = warmup.first?.slug
            ?? exercises.first?.slug
            ?? cooldown.first?.slug
            ?? heroSlug(for: seed.id, name: seed.name)
        return Routine(
            id: seed.id,
            name: seed.name,
            focus: seed.focus,
            summary: summary(for: seed.id, focus: seed.focus),
            heroSlug: thumb,
            rotationIndex: rotationIndex,
            warmup: warmup,
            exercises: exercises,
            cooldown: cooldown,
            minutes: 60,
            difficulty: 3,
            washGrade: WashGrade.forShippingRoutine(seed.id)
        )
    }

    private static func summary(for id: String, focus: String) -> String {
        switch id {
        case "A":
            return "Build your pressing foundation with dumbbell and cable movements for the chest, shoulders, and triceps. Choose comfortable ranges and controlled reps."
        case "B":
            return "Build lower-body control with machine work for the hips, legs, and trunk. Stay in a comfortable range and keep each rep steady."
        case "C":
            return "Build the back, arms, and grip with cable pulling and assisted pull-ups. Log the assistance, not added weight."
        case "D":
            return "Build a lower-body foundation and trunk control with bridges, squats, steps, and bracing. Use a comfortable depth and slow reps."
        default:
            return focus
        }
    }

    private static func heroSlug(for id: String, name: String) -> String {
        switch id {
        case "A": return "standing-dumbbell-press"
        case "B": return "leg-extension"
        case "C": return "seated-row"
        case "D": return "step-up"
        default: return illustrationSlug(for: name)
        }
    }

    private enum GuidePhase {
        case warmup, cooldown
    }

    private static func guideSteps(routineId: String, phase: GuidePhase, instructions: String) -> [GuideStep] {
        if routineId == "A" {
            switch phase {
            case .warmup:
                return [
                    GuideStep(id: "\(routineId)-warmup-walking", title: "Easy Walk", metaParts: ["3–5 minutes"], slug: "walking"),
                    GuideStep(id: "\(routineId)-warmup-arm-circles", title: "Shoulder Circles", metaParts: ["30 seconds", "2 sets"], slug: "arm-circles"),
                    GuideStep(id: "\(routineId)-warmup-rear-delt", title: "Band External Rotations", metaParts: ["12 reps", "2 sets"], slug: "cable-rear-delt-fly"),
                    GuideStep(id: "\(routineId)-warmup-bench", title: "Progressive Light Bench", metaParts: ["10 reps", "2 sets"], slug: "dumbbell-bench-press"),
                ]
            case .cooldown:
                return [
                    GuideStep(id: "\(routineId)-cooldown-walking", title: "Easy Walk", metaParts: ["3 minutes"], slug: "walking"),
                    GuideStep(id: "\(routineId)-cooldown-shoulder", title: "Shoulder Stretch", metaParts: ["30 seconds each side"], slug: "cross-body-shoulder-stretch"),
                    GuideStep(id: "\(routineId)-cooldown-chest", title: "Standing Chest Stretch", metaParts: ["30 seconds each side"], slug: "doorway-chest-stretch"),
                ]
            }
        }
        let phaseKey = phase == .warmup ? "warmup" : "cooldown"
        return instructions
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, label in
                let presented = presentStep(label)
                let slug = illustrationSlug(for: label)
                return GuideStep(
                    id: "\(routineId)-\(phaseKey)-\(index)-\(slug)",
                    title: presented.title,
                    metaParts: presented.metaParts,
                    slug: slug
                )
            }
    }

    /// Pulls duration / sets / reps out of guide copy so tiles match main-workout title + meta layout.
    private static func presentStep(_ label: String) -> (title: String, metaParts: [String]) {
        let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let minutesPattern = #"^(\d+)\s*min(?:ute)?s?\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: minutesPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           let minutesRange = Range(match.range(at: 1), in: cleaned),
           let restRange = Range(match.range(at: 2), in: cleaned) {
            return (sentence(String(cleaned[restRange])), ["\(cleaned[minutesRange]) minutes"])
        }
        let setsPattern = #"^(.+?)\s+(\d+)\s*[×xX]\s*(\d+)\s*(.*)$"#
        if let regex = try? NSRegularExpression(pattern: setsPattern),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           let nameRange = Range(match.range(at: 1), in: cleaned),
           let setsRange = Range(match.range(at: 2), in: cleaned),
           let repsRange = Range(match.range(at: 3), in: cleaned),
           let tailRange = Range(match.range(at: 4), in: cleaned) {
            let sets = Int(cleaned[setsRange]) ?? 0
            let reps = Int(cleaned[repsRange]) ?? 0
            let tail = String(cleaned[tailRange]).trimmingCharacters(in: .whitespaces)
            var parts = [
                "\(reps) reps",
                "\(sets) \(sets == 1 ? "set" : "sets")",
            ]
            if !tail.isEmpty {
                parts.append(tail)
            }
            return (sentence(String(cleaned[nameRange])), parts)
        }
        return (sentence(cleaned), [])
    }

    private static func sentence(_ value: String) -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }

    private static func displayWeight(for name: String) -> String {
        switch name {
        case "Dumbbell Bench Press", "Cable Triceps Pushdown":
            return "45 lbs"
        case "Cable Bench Press":
            return "25 lbs"
        case "Dumbbell Shoulder Press":
            return "20 lbs"
        case "Dumbbell Lateral Raise":
            return "10 lbs"
        default:
            return "—"
        }
    }

    static func illustrationSlug(for name: String) -> String {
        let options: String.CompareOptions = [.regularExpression, .caseInsensitive]
        if name.range(of: "shoulder press|overhead press", options: options) != nil {
            return "standing-dumbbell-press"
        }
        if name.range(of: "cable bench|cable fly", options: options) != nil {
            return "cable-fly"
        }
        if name.range(of: "bench press|\\bbench\\b", options: options) != nil {
            return "dumbbell-bench-press"
        }
        if name.range(of: "lateral raise", options: options) != nil {
            return "lateral-raise"
        }
        if name.range(of: "pushdown|tricep", options: options) != nil {
            return "tricep-pushdown"
        }
        if name.range(of: "leg curl", options: options) != nil { return "seated-leg-curl" }
        if name.range(of: "leg extension", options: options) != nil { return "leg-extension" }
        if name.range(of: "abduction", options: options) != nil { return "hip-abduction-machine" }
        if name.range(of: "adduction", options: options) != nil { return "hip-adduction-machine" }
        if name.range(of: "calf", options: options) != nil { return "standing-calf-raise" }
        if name.range(of: "pallof", options: options) != nil { return "pallof-press" }
        if name.range(of: "pull-?up", options: options) != nil { return "assisted-pull-up" }
        if name.range(of: "pulldown", options: options) != nil { return "lat-pulldown" }
        if name.range(of: "face pull", options: options) != nil { return "face-pull" }
        if name.range(of: "farmer", options: options) != nil { return "farmer-carry" }
        if name.range(of: "biceps|\\bcurl\\b", options: options) != nil { return "cable-curl" }
        if name.range(of: "cable row|seated row|\\brow\\b", options: options) != nil { return "seated-row" }
        if name.range(of: "glute bridge", options: options) != nil { return "glute-bridge" }
        if name.range(of: "step-?up", options: options) != nil { return "step-up" }
        if name.range(of: "bird dog", options: options) != nil { return "bird-dog" }
        if name.range(of: "squat", options: options) != nil { return "bodyweight-squat" }
        if name.range(of: "clamshell", options: options) != nil { return "clamshell" }
        if name.range(of: "leg swing", options: options) != nil { return "leg-swings-stretch" }
        if name.range(of: "hip flexor", options: options) != nil { return "kneeling-hip-flexor-stretch" }
        if name.range(of: "hamstring", options: options) != nil { return "hamstring-stretch" }
        if name.range(of: "external rotation", options: options) != nil { return "cable-rear-delt-fly" }
        if name.range(of: "shoulder circle|arm circle|scapular motion", options: options) != nil { return "arm-circles" }
        if name.range(of: "scapular", options: options) != nil { return "band-pull-apart" }
        if name.range(of: "hinge", options: options) != nil { return "dumbbell-romanian-deadlift" }
        if name.range(of: "\\bbike\\b", options: options) != nil { return "assault-bike" }
        if name.range(of: "march", options: options) != nil { return "high-knees" }
        if name.range(of: "hip circle|breath|relaxed", options: options) != nil { return "cat-cow-stretch" }
        if name.range(of: "walk", options: options) != nil { return "walking" }
        return "walking"
    }
}
