import Foundation
import Observation

struct LoggedLift: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var sets: Int
    var weight: String
}

struct FinishedSession: Codable, Identifiable, Hashable {
    let id: UUID
    let routineId: String
    let routineName: String
    let finishedAt: Date
    let exerciseIds: [String]
    var durationMinutes: Int
    var lifts: [LoggedLift]

    var totalSets: Int {
        lifts.reduce(0) { $0 + $1.sets }
    }

    enum CodingKeys: String, CodingKey {
        case id, routineId, routineName, finishedAt, exerciseIds, durationMinutes, lifts
    }

    init(
        id: UUID = UUID(),
        routineId: String,
        routineName: String,
        finishedAt: Date,
        exerciseIds: [String],
        durationMinutes: Int,
        lifts: [LoggedLift]
    ) {
        self.id = id
        self.routineId = routineId
        self.routineName = routineName
        self.finishedAt = finishedAt
        self.exerciseIds = exerciseIds
        self.durationMinutes = durationMinutes
        self.lifts = lifts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        routineId = try container.decode(String.self, forKey: .routineId)
        routineName = try container.decode(String.self, forKey: .routineName)
        finishedAt = try container.decode(Date.self, forKey: .finishedAt)
        exerciseIds = try container.decodeIfPresent([String].self, forKey: .exerciseIds) ?? []
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 60
        lifts = try container.decodeIfPresent([LoggedLift].self, forKey: .lifts) ?? []
    }
}

struct HistoryStats {
    var workoutsCompleted: Int
    var thisWeek: Int
    var thisMonth: Int
    var currentStreak: Int
    var totalMinutes: Int
    var totalSets: Int
    var routineMix: [(name: String, count: Int)]
}

@Observable
final class SessionStore {
    private(set) var sessions: [FinishedSession] = []
    private let url: URL
    private let seededKey = "foundation.history.seeded.v1"

    init(fileManager: FileManager = .default) {
        let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appending(path: "Foundation", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appending(path: "sessions.json")
        sessions = Self.read(from: url)
        seedIfNeeded()
    }

    var stats: HistoryStats {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now

        let thisWeek = sessions.filter { $0.finishedAt >= weekStart }.count
        let thisMonth = sessions.filter { $0.finishedAt >= monthStart }.count
        let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        let totalSets = sessions.reduce(0) { $0 + $1.totalSets }

        var mix: [String: Int] = [:]
        for session in sessions {
            mix[session.routineName, default: 0] += 1
        }
        let routineMix = mix
            .map { (name: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.name < rhs.name }
                return lhs.count > rhs.count
            }

        return HistoryStats(
            workoutsCompleted: sessions.count,
            thisWeek: thisWeek,
            thisMonth: thisMonth,
            currentStreak: Self.streak(in: sessions, calendar: calendar, now: now),
            totalMinutes: totalMinutes,
            totalSets: totalSets,
            routineMix: routineMix
        )
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

    func complete(_ routine: Routine, weights: [String: String] = [:]) {
        let lifts = routine.exercises.map { exercise in
            LoggedLift(
                id: exercise.id,
                name: exercise.name,
                sets: exercise.sets,
                weight: weights[exercise.id] ?? exercise.displayWeight ?? "—"
            )
        }
        let session = FinishedSession(
            routineId: routine.id,
            routineName: routine.name,
            finishedAt: Date(),
            exerciseIds: routine.exercises.map(\.id),
            durationMinutes: routine.minutes,
            lifts: lifts
        )
        sessions.insert(session, at: 0)
        persist()
    }

    func update(_ session: FinishedSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[index] = session
        persist()
    }

    private func persist() {
        Self.write(sessions, to: url)
    }

    private func seedIfNeeded() {
        guard sessions.isEmpty, !UserDefaults.standard.bool(forKey: seededKey) else { return }
        sessions = Self.sampleSessions()
        persist()
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    private static func streak(in sessions: [FinishedSession], calendar: Calendar, now: Date) -> Int {
        let days = Set(sessions.map { calendar.startOfDay(for: $0.finishedAt) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday)
            else {
                return 0
            }
            cursor = yesterday
        }

        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private static func sampleSessions() -> [FinishedSession] {
        let calendar = Calendar.current
        let now = Date()
        func day(_ offset: Int, hour: Int = 18) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: 30, second: 0, of: base) ?? base
        }

        return [
            FinishedSession(
                routineId: "A",
                routineName: "Upper Push",
                finishedAt: day(-1),
                exerciseIds: ["A-bench", "A-fly", "A-press", "A-raise", "A-pushdown"],
                durationMinutes: 58,
                lifts: [
                    LoggedLift(id: "A-bench", name: "Dumbbell Bench Press", sets: 3, weight: "45 lbs"),
                    LoggedLift(id: "A-fly", name: "Cable Bench Press", sets: 3, weight: "25 lbs"),
                    LoggedLift(id: "A-press", name: "Dumbbell Shoulder Press", sets: 3, weight: "20 lbs"),
                    LoggedLift(id: "A-raise", name: "Dumbbell Lateral Raise", sets: 3, weight: "10 lbs"),
                    LoggedLift(id: "A-pushdown", name: "Cable Triceps Pushdown", sets: 3, weight: "45 lbs"),
                ]
            ),
            FinishedSession(
                routineId: "B",
                routineName: "Lower Stability",
                finishedAt: day(-2, hour: 17),
                exerciseIds: ["B-curl", "B-ext", "B-abd"],
                durationMinutes: 55,
                lifts: [
                    LoggedLift(id: "B-curl", name: "Seated Leg Curl", sets: 3, weight: "70 lbs"),
                    LoggedLift(id: "B-ext", name: "Leg Extension", sets: 3, weight: "80 lbs"),
                    LoggedLift(id: "B-abd", name: "Hip Abduction", sets: 3, weight: "60 lbs"),
                ]
            ),
            FinishedSession(
                routineId: "C",
                routineName: "Upper Pull",
                finishedAt: day(-4),
                exerciseIds: ["C-pull", "C-row", "C-face"],
                durationMinutes: 62,
                lifts: [
                    LoggedLift(id: "C-pull", name: "Assisted Pull-Up", sets: 3, weight: "40 lbs"),
                    LoggedLift(id: "C-row", name: "Seated Row", sets: 3, weight: "90 lbs"),
                    LoggedLift(id: "C-face", name: "Face Pull", sets: 3, weight: "35 lbs"),
                ]
            ),
            FinishedSession(
                routineId: "D",
                routineName: "Lower Strength + Core",
                finishedAt: day(-6, hour: 19),
                exerciseIds: ["D-squat", "D-step", "D-bridge"],
                durationMinutes: 60,
                lifts: [
                    LoggedLift(id: "D-squat", name: "Bodyweight Squat", sets: 3, weight: "—"),
                    LoggedLift(id: "D-step", name: "Step-Up", sets: 3, weight: "20 lbs"),
                    LoggedLift(id: "D-bridge", name: "Glute Bridge", sets: 3, weight: "—"),
                ]
            ),
            FinishedSession(
                routineId: "A",
                routineName: "Upper Push",
                finishedAt: day(-8),
                exerciseIds: ["A-bench", "A-fly", "A-press"],
                durationMinutes: 50,
                lifts: [
                    LoggedLift(id: "A-bench", name: "Dumbbell Bench Press", sets: 3, weight: "40 lbs"),
                    LoggedLift(id: "A-fly", name: "Cable Bench Press", sets: 3, weight: "20 lbs"),
                    LoggedLift(id: "A-press", name: "Dumbbell Shoulder Press", sets: 3, weight: "20 lbs"),
                ]
            ),
            FinishedSession(
                routineId: "B",
                routineName: "Lower Stability",
                finishedAt: day(-10),
                exerciseIds: ["B-curl", "B-ext"],
                durationMinutes: 48,
                lifts: [
                    LoggedLift(id: "B-curl", name: "Seated Leg Curl", sets: 3, weight: "65 lbs"),
                    LoggedLift(id: "B-ext", name: "Leg Extension", sets: 3, weight: "75 lbs"),
                ]
            ),
        ].sorted { $0.finishedAt > $1.finishedAt }
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
