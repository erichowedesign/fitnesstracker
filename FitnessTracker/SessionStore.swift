import Foundation
import Observation

struct FinishedSession: Codable, Identifiable {
    let id: UUID
    let routineId: String
    let routineName: String
    let finishedAt: Date
    let exerciseIds: [String]
}

@Observable
final class SessionStore {
    private(set) var sessions: [FinishedSession] = []
    private let url: URL

    init(fileManager: FileManager = .default) {
        let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appending(path: "Foundation", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appending(path: "sessions.json")
        sessions = Self.read(from: url)
    }

    func nextRoutine(in routines: [Routine]) -> Routine {
        guard let first = routines.first else {
            fatalError("No routines in the plan.")
        }
        guard let lastId = sessions.first?.routineId,
              let index = routines.firstIndex(where: { $0.id == lastId })
        else {
            return first
        }
        return routines[(index + 1) % routines.count]
    }

    func remainingRoutines(after upNext: Routine, in routines: [Routine]) -> [Routine] {
        guard let index = routines.firstIndex(where: { $0.id == upNext.id }) else {
            return routines
        }
        return (1..<routines.count).map { offset in
            routines[(index + offset) % routines.count]
        }
    }

    func complete(_ routine: Routine) {
        let session = FinishedSession(
            id: UUID(),
            routineId: routine.id,
            routineName: routine.name,
            finishedAt: Date(),
            exerciseIds: routine.exercises.map(\.id)
        )
        sessions.insert(session, at: 0)
        Self.write(sessions, to: url)
    }

    private static func read(from url: URL) -> [FinishedSession] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([FinishedSession].self, from: data)) ?? []
    }

    private static func write(_ sessions: [FinishedSession], to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
