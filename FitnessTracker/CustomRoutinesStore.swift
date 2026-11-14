import Foundation
import Observation

/// User-created routines (separate from shipping A–D + RoutineOverridesStore).
@Observable
final class CustomRoutinesStore {
    private(set) var customs: [PersistedCustomRoutine] = []
    private let url: URL

    init(fileManager: FileManager = .default) {
        let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appending(path: "Foundation", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appending(path: "custom-routines.json")
        customs = Self.read(from: url)
    }

    /// Routines for Home / navigation, resolved to `Routine` models.
    func routines(startingRotationAt startIndex: Int) -> [Routine] {
        customs.enumerated().map { offset, custom in
            custom.asRoutine(rotationIndex: startIndex + offset)
        }
    }

    func contains(_ routineID: String) -> Bool {
        customs.contains { $0.id == routineID }
    }

    func routine(id: String) -> Routine? {
        guard let index = customs.firstIndex(where: { $0.id == id }) else { return nil }
        let start = WorkoutPlan.all().count + 1
        return customs[index].asRoutine(rotationIndex: start + index)
    }

    /// Creates an empty custom routine shell and persists it.
    @discardableResult
    func create(
        name: String,
        includesWarmup: Bool,
        includesMain: Bool,
        includesCooldown: Bool
    ) -> Routine {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = "custom-\(UUID().uuidString.lowercased())"
        let focus = Self.focusLabel(
            warmup: includesWarmup,
            main: includesMain,
            cooldown: includesCooldown
        )
        let persisted = PersistedCustomRoutine(
            id: id,
            name: trimmed,
            focus: focus,
            includesWarmup: includesWarmup,
            includesMain: includesMain,
            includesCooldown: includesCooldown,
            warmup: includesWarmup ? [] : nil,
            exercises: includesMain ? [] : nil,
            cooldown: includesCooldown ? [] : nil
        )
        customs.append(persisted)
        persist()
        let start = WorkoutPlan.all().count + 1
        return persisted.asRoutine(rotationIndex: start + customs.count - 1)
    }

    func save(
        warmup: [GuideStep],
        exercises: [Exercise],
        cooldown: [GuideStep],
        for routineID: String
    ) {
        guard let index = customs.firstIndex(where: { $0.id == routineID }) else { return }
        var current = customs[index]
        if current.includesWarmup {
            current.warmup = warmup.map(PersistedGuideStep.init)
        } else {
            current.warmup = nil
        }
        if current.includesMain {
            current.exercises = exercises.map(PersistedExercise.init)
        } else {
            current.exercises = nil
        }
        if current.includesCooldown {
            current.cooldown = cooldown.map(PersistedGuideStep.init)
        } else {
            current.cooldown = nil
        }
        customs[index] = current
        persist()
    }

    func delete(id: String) {
        guard customs.contains(where: { $0.id == id }) else { return }
        customs.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        Self.write(customs, to: url)
    }

    private static func focusLabel(warmup: Bool, main: Bool, cooldown: Bool) -> String {
        var parts: [String] = []
        if warmup { parts.append("Warm-up") }
        if main { parts.append("Main") }
        if cooldown { parts.append("Cool Down") }
        if parts.isEmpty { return "Custom routine" }
        return parts.joined(separator: " · ")
    }

    private static func read(from url: URL) -> [PersistedCustomRoutine] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([PersistedCustomRoutine].self, from: data)) ?? []
    }

    private static func write(_ value: [PersistedCustomRoutine], to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

struct PersistedCustomRoutine: Codable, Equatable {
    var id: String
    var name: String
    var focus: String
    var includesWarmup: Bool
    var includesMain: Bool
    var includesCooldown: Bool
    var warmup: [PersistedGuideStep]?
    var exercises: [PersistedExercise]?
    var cooldown: [PersistedGuideStep]?

    func asRoutine(rotationIndex: Int) -> Routine {
        let warmupSteps = includesWarmup ? (warmup ?? []).map(\.asGuideStep) : []
        let main = includesMain ? (exercises ?? []).map(\.asExercise) : []
        let cooldownSteps = includesCooldown ? (cooldown ?? []).map(\.asGuideStep) : []
        let minutes = max(20, main.count * 8 + (includesWarmup ? 8 : 0) + (includesCooldown ? 5 : 0))
        return Routine(
            id: id,
            name: name,
            focus: focus,
            summary: focus,
            heroSlug: main.first?.slug ?? "bodyweight-squat",
            rotationIndex: rotationIndex,
            warmup: warmupSteps,
            exercises: main,
            cooldown: cooldownSteps,
            minutes: minutes,
            difficulty: 3,
            includesWarmup: includesWarmup,
            includesMain: includesMain,
            includesCooldown: includesCooldown,
            isCustom: true
        )
    }
}
