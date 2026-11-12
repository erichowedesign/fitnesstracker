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

struct Routine: Identifiable {
    let id: String
    let name: String
    let focus: String
    let summary: String
    let heroSlug: String
    let warmup: [GuideStep]
    let exercises: [Exercise]
    let cooldown: [GuideStep]
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

    static func upperPush() -> Routine {
        guard let seed = load().routines.first(where: { $0.id == "A" }) else {
            fatalError("Upper Push (routine A) is missing from workouts.json.")
        }
        return Routine(
            id: seed.id,
            name: seed.name,
            focus: seed.focus,
            summary: "Build your pressing foundation with dumbbell and cable movements for the chest, shoulders, and triceps. Choose comfortable ranges and controlled reps.",
            heroSlug: "standing-dumbbell-press",
            warmup: [
                GuideStep(title: "Easy Walk", metaParts: ["3–5 minutes"], slug: "walking"),
                GuideStep(title: "Shoulder Circles", metaParts: ["30 seconds", "2 sets"], slug: "arm-circles"),
                GuideStep(title: "Band External Rotations", metaParts: ["12 reps", "2 sets"], slug: "cable-rear-delt-fly"),
                GuideStep(title: "Progressive Light Bench", metaParts: ["10 reps", "2 sets"], slug: "dumbbell-bench-press"),
            ],
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
            cooldown: [
                GuideStep(title: "Easy Walk", metaParts: ["3 minutes"], slug: "walking"),
                GuideStep(title: "Shoulder Stretch", metaParts: ["30 seconds each side"], slug: "cross-body-shoulder-stretch"),
                GuideStep(title: "Standing Chest Stretch", metaParts: ["30 seconds each side"], slug: "doorway-chest-stretch"),
            ]
        )
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
        return "walking"
    }
}
