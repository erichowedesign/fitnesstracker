import Foundation
import Observation

/// Local main-workout overrides keyed by routine id. Survives leaving the screen.
@Observable
final class RoutineOverridesStore {
    private var overrides: [String: [PersistedExercise]] = [:]
    private let url: URL

    init(fileManager: FileManager = .default) {
        let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appending(path: "Foundation", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appending(path: "routine-overrides.json")
        overrides = Self.read(from: url)
    }

    func resolved(_ routine: Routine) -> Routine {
        guard let saved = overrides[routine.id], !saved.isEmpty else { return routine }
        return routine.withExercises(saved.map(\.asExercise))
    }

    func exercises(for routineID: String, fallback: [Exercise]) -> [Exercise] {
        if let saved = overrides[routineID], !saved.isEmpty {
            return saved.map(\.asExercise)
        }
        return fallback
    }

    func save(exercises: [Exercise], for routineID: String) {
        overrides[routineID] = exercises.map(PersistedExercise.init)
        persist()
    }

    func clear(routineID: String) {
        overrides.removeValue(forKey: routineID)
        persist()
    }

    private func persist() {
        Self.write(overrides, to: url)
    }

    private static func read(from url: URL) -> [String: [PersistedExercise]] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [PersistedExercise]].self, from: data)) ?? [:]
    }

    private static func write(_ value: [String: [PersistedExercise]], to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
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
