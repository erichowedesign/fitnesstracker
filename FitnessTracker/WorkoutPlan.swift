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

    var exerciseCountLabel: String {
        String(format: "%02d", exercises.count)
    }

    var workoutsLine: String {
        "\(exerciseCountLabel) workouts / \(minutes) minutes"
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
        switch name {
        case "Dumbbell Bench Press":
            return [
                "Keep your core engaged and your head, shoulders, and back flat against the pad",
                "Avoid locking out your elbows at the top",
                "Your arms should stay at roughly 90-degree angles at the bottom",
            ]
        default:
            return []
        }
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

    private static func restLabel(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", remainder)) rest"
        }
        return "\(seconds) sec rest"
    }
}

struct GuideStep: Identifiable {
    var id: String { title }
    let title: String
    let metaParts: [String]
    let slug: String
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
        Routine(
            id: seed.id,
            name: seed.name,
            focus: seed.focus,
            summary: summary(for: seed.id, focus: seed.focus),
            heroSlug: heroSlug(for: seed.id, name: seed.name),
            rotationIndex: rotationIndex,
            warmup: guideSteps(routineId: seed.id, phase: .warmup, instructions: seed.warmup.instructions),
            exercises: seed.exercises.map { exercise in
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
            },
            cooldown: guideSteps(routineId: seed.id, phase: .cooldown, instructions: seed.cooldown.instructions),
            minutes: 60,
            difficulty: 3
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
                    GuideStep(title: "Easy Walk", metaParts: ["3–5 minutes"], slug: "walking"),
                    GuideStep(title: "Shoulder Circles", metaParts: ["30 seconds", "2 sets"], slug: "arm-circles"),
                    GuideStep(title: "Band External Rotations", metaParts: ["12 reps", "2 sets"], slug: "cable-rear-delt-fly"),
                    GuideStep(title: "Progressive Light Bench", metaParts: ["10 reps", "2 sets"], slug: "dumbbell-bench-press"),
                ]
            case .cooldown:
                return [
                    GuideStep(title: "Easy Walk", metaParts: ["3 minutes"], slug: "walking"),
                    GuideStep(title: "Shoulder Stretch", metaParts: ["30 seconds each side"], slug: "cross-body-shoulder-stretch"),
                    GuideStep(title: "Standing Chest Stretch", metaParts: ["30 seconds each side"], slug: "doorway-chest-stretch"),
                ]
            }
        }
        return instructions
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { label in
                let presented = presentStep(label)
                return GuideStep(
                    title: presented.title,
                    metaParts: presented.meta.isEmpty ? [] : [presented.meta],
                    slug: illustrationSlug(for: label)
                )
            }
    }

    private static func presentStep(_ label: String) -> (title: String, meta: String) {
        let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let pattern = #"^(\d+)\s*min(?:ute)?s?\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           let minutesRange = Range(match.range(at: 1), in: cleaned),
           let restRange = Range(match.range(at: 2), in: cleaned) {
            return (sentence(String(cleaned[restRange])), "\(cleaned[minutesRange]) minutes")
        }
        return (sentence(cleaned), "")
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
