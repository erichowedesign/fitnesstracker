import Foundation
import Observation

/// Local routine section overrides keyed by routine id. Survives leaving the screen.
@Observable
final class RoutineOverridesStore {
    private var overrides: [String: PersistedRoutineOverride] = [:]
    private let url: URL

    init(fileManager: FileManager = .default) {
        let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appending(path: "Foundation", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appending(path: "routine-overrides.json")
        overrides = Self.read(from: url)
    }

    func resolved(_ routine: Routine) -> Routine {
        guard let saved = overrides[routine.id] else { return routine }
        var next = routine.withSections(
            warmup: saved.warmup?.map(\.asGuideStep),
            exercises: saved.exercises?.map(\.asExercise),
            cooldown: saved.cooldown?.map(\.asGuideStep)
        )
        if let raw = saved.washGradeRaw, let grade = WashGrade(rawValue: raw) {
            next.washGrade = grade
        }
        return next
    }

    func washGrade(for routineID: String, fallback: WashGrade) -> WashGrade {
        if let raw = overrides[routineID]?.washGradeRaw, let grade = WashGrade(rawValue: raw) {
            return grade
        }
        return fallback
    }

    func exercises(for routineID: String, fallback: [Exercise]) -> [Exercise] {
        if let saved = overrides[routineID]?.exercises {
            return saved.map(\.asExercise)
        }
        return fallback
    }

    func warmup(for routineID: String, fallback: [GuideStep]) -> [GuideStep] {
        if let saved = overrides[routineID]?.warmup {
            return saved.map(\.asGuideStep)
        }
        return fallback
    }

    func cooldown(for routineID: String, fallback: [GuideStep]) -> [GuideStep] {
        if let saved = overrides[routineID]?.cooldown {
            return saved.map(\.asGuideStep)
        }
        return fallback
    }

    func save(
        warmup: [GuideStep],
        exercises: [Exercise],
        cooldown: [GuideStep],
        for routineID: String
    ) {
        var next = overrides
        var current = next[routineID] ?? PersistedRoutineOverride()
        current.warmup = warmup.map(PersistedGuideStep.init)
        current.exercises = exercises.map(PersistedExercise.init)
        current.cooldown = cooldown.map(PersistedGuideStep.init)
        next[routineID] = current
        overrides = next
        persist()
    }

    /// Legacy entry point — preserves existing guide sections when only main changes.
    func save(exercises: [Exercise], for routineID: String) {
        var current = overrides[routineID] ?? PersistedRoutineOverride()
        current.exercises = exercises.map(PersistedExercise.init)
        overrides[routineID] = current
        persist()
    }

    func setWashGrade(_ grade: WashGrade, for routineID: String) {
        var next = overrides
        var current = next[routineID] ?? PersistedRoutineOverride()
        current.washGradeRaw = grade.rawValue
        next[routineID] = current
        overrides = next
        persist()
    }

    func clear(routineID: String) {
        overrides.removeValue(forKey: routineID)
        persist()
    }

    /// Restore every routine to the bundled WorkoutPlan (warm-up, main, cool-down).
    func clearAll() {
        overrides = [:]
        persist()
    }

    var hasOverrides: Bool { !overrides.isEmpty }

    private func persist() {
        Self.write(overrides, to: url)
    }

    private static func read(from url: URL) -> [String: PersistedRoutineOverride] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        if let modern = try? JSONDecoder().decode([String: PersistedRoutineOverride].self, from: data) {
            return modern
        }
        // Older builds stored only main-workout arrays.
        if let legacy = try? JSONDecoder().decode([String: [PersistedExercise]].self, from: data) {
            return legacy.mapValues { PersistedRoutineOverride(exercises: $0) }
        }
        return [:]
    }

    private static func write(_ value: [String: PersistedRoutineOverride], to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

struct PersistedRoutineOverride: Codable, Equatable {
    var warmup: [PersistedGuideStep]?
    var exercises: [PersistedExercise]?
    var cooldown: [PersistedGuideStep]?
    /// Optional wash theme override (`WashGrade.rawValue`).
    var washGradeRaw: String?
}

struct PersistedGuideStep: Codable, Equatable {
    var id: String
    var title: String
    var metaParts: [String]
    var slug: String

    init(_ step: GuideStep) {
        id = step.id
        title = step.title
        metaParts = step.metaParts
        slug = step.slug
    }

    var asGuideStep: GuideStep {
        GuideStep(id: id, title: title, metaParts: metaParts, slug: slug)
    }
}

struct PersistedExercise: Codable, Equatable {
    var id: String
    var hevyTemplateId: String
    var name: String
    var equipment: String
    var sets: Int
    var targetReps: Int?
    var targetDurationSeconds: Int?
    var restSeconds: Int
    var notes: String
    var tracksAssistance: Bool
    var slug: String
    var displayWeight: String?

    init(_ exercise: Exercise) {
        id = exercise.id
        hevyTemplateId = exercise.hevyTemplateId
        name = exercise.name
        equipment = exercise.equipment
        sets = exercise.sets
        targetReps = exercise.targetReps
        targetDurationSeconds = exercise.targetDurationSeconds
        restSeconds = exercise.restSeconds
        notes = exercise.notes
        tracksAssistance = exercise.tracksAssistance
        slug = exercise.slug
        displayWeight = exercise.displayWeight
    }

    var asExercise: Exercise {
        Exercise(
            id: id,
            hevyTemplateId: hevyTemplateId,
            name: name,
            equipment: equipment,
            sets: sets,
            targetReps: targetReps,
            targetDurationSeconds: targetDurationSeconds,
            restSeconds: restSeconds,
            notes: notes,
            tracksAssistance: tracksAssistance,
            slug: slug,
            displayWeight: displayWeight
        )
    }
}
