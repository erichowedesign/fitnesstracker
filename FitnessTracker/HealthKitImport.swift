import Foundation
import HealthKit
import Observation

/// Snapshot of an Apple Health / Watch workout Foundation can link to a session.
struct HealthWorkoutCandidate: Identifiable, Hashable {
    var id: UUID { workoutUUID }
    let workoutUUID: UUID
    let activityName: String
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: TimeInterval
    var activeEnergyKcal: Double?
    var averageHeartRateBPM: Double?
    var maxHeartRateBPM: Double?
    /// Distance in meters when HealthKit provides it (walk/run/cycle, etc.).
    var totalDistanceMeters: Double?

    var durationMinutesRounded: Int {
        max(Int((durationSeconds / 60).rounded()), 1)
    }

    var summaryLine: String {
        var parts: [String] = [
            activityName,
            "\(durationMinutesRounded) min",
        ]
        if let activeEnergyKcal {
            parts.append("\(Int(activeEnergyKcal.rounded())) kcal")
        }
        if let averageHeartRateBPM {
            parts.append("avg \(Int(averageHeartRateBPM.rounded())) bpm")
        }
        if let totalDistanceMeters, totalDistanceMeters > 0 {
            parts.append(Self.formatDistance(meters: totalDistanceMeters))
        }
        return parts.joined(separator: " · ")
    }

    var asLinkedHealthWorkout: LinkedHealthWorkout {
        LinkedHealthWorkout(
            workoutUUID: workoutUUID,
            activityName: activityName,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: durationSeconds,
            activeEnergyKcal: activeEnergyKcal,
            averageHeartRateBPM: averageHeartRateBPM,
            maxHeartRateBPM: maxHeartRateBPM,
            totalDistanceMeters: totalDistanceMeters
        )
    }

    static func formatDistance(meters: Double) -> String {
        let miles = meters / 1609.344
        if miles >= 0.1 {
            return String(format: "%.2f mi", miles)
        }
        return "\(Int(meters.rounded())) m"
    }
}

enum HealthImportError: LocalizedError {
    case unavailable
    case notAuthorized
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health isn’t available on this device."
        case .notAuthorized:
            return "Foundation needs permission to read workouts from Apple Health."
        case .queryFailed(let message):
            return message
        }
    }
}

/// Read-only HealthKit import for linking Watch / Health workouts to Foundation sessions.
@Observable
final class HealthImportStore {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        if let heart = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heart)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let cycling = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            types.insert(cycling)
        }
        return types
    }

    /// Request read access the first time the user taps Scan.
    func requestAuthorizationIfNeeded() async throws {
        guard isAvailable else { throw HealthImportError.unavailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Workouts whose end time falls inside `range` (inclusive), newest first.
    func workouts(endingIn range: ClosedRange<Date>) async throws -> [HealthWorkoutCandidate] {
        guard isAvailable else { throw HealthImportError.unavailable }
        try await requestAuthorizationIfNeeded()

        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(
            withStart: range.lowerBound,
            end: range.upperBound,
            options: .strictEndDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: HealthImportError.queryFailed(error.localizedDescription))
                    return
                }
                continuation.resume(returning: results ?? [])
            }
            store.execute(query)
        }

        var candidates: [HealthWorkoutCandidate] = []
        for sample in samples {
            guard let workout = sample as? HKWorkout else { continue }
            let enriched = await enrich(workout)
            candidates.append(enriched)
        }
        return candidates
    }

    /// Recent workouts ending near `anchor` (default: now), for the Complete-workout Scan.
    /// Gives Watch a few seconds after stop; looks back `lookback` for the end time.
    func recentWorkoutsNearNow(
        anchor: Date = Date(),
        lookback: TimeInterval = 45 * 60,
        graceAfter: TimeInterval = 3 * 60
    ) async throws -> [HealthWorkoutCandidate] {
        let start = anchor.addingTimeInterval(-lookback)
        let end = anchor.addingTimeInterval(graceAfter)
        return try await workouts(endingIn: start...end)
    }

    func workouts(inLastDays days: Int, endingBefore end: Date = Date()) async throws -> [HealthWorkoutCandidate] {
        let start = Calendar.current.date(byAdding: .day, value: -max(days, 1), to: end)
            ?? end.addingTimeInterval(-86_400)
        return try await workouts(endingIn: start...end)
    }

    private func enrich(_ workout: HKWorkout) async -> HealthWorkoutCandidate {
        let activityName = workout.workoutActivityType.foundationDisplayName
        let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())

        let distanceMeters = workout.totalDistance?.doubleValue(for: .meter())
        let hr = await heartRateSummary(for: workout)

        return HealthWorkoutCandidate(
            workoutUUID: workout.uuid,
            activityName: activityName,
            startedAt: workout.startDate,
            endedAt: workout.endDate,
            durationSeconds: workout.duration,
            activeEnergyKcal: energy,
            averageHeartRateBPM: hr.average,
            maxHeartRateBPM: hr.max,
            totalDistanceMeters: distanceMeters
        )
    }

    private func heartRateSummary(for workout: HKWorkout) async -> (average: Double?, max: Double?) {
        guard let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return (nil, nil)
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }

        guard !samples.isEmpty else { return (nil, nil) }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        let average = values.reduce(0, +) / Double(values.count)
        let maxValue = values.max()
        return (average, maxValue)
    }
}

extension HKWorkoutActivityType {
    var foundationDisplayName: String {
        switch self {
        case .traditionalStrengthTraining: return "Strength"
        case .functionalStrengthTraining: return "Functional strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .coreTraining: return "Core"
        case .flexibility: return "Flexibility"
        case .cooldown: return "Cool down"
        case .yoga: return "Yoga"
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stairs"
        case .swimBikeRun: return "Triathlon"
        case .mixedCardio: return "Mixed cardio"
        case .other: return "Other workout"
        default:
            return "Workout"
        }
    }
}

enum HealthSessionMatching {
    /// Prefer Foundation sessions without a Health link whose finish time is near the workout end.
    static func suggestedSession(
        for candidate: HealthWorkoutCandidate,
        in sessions: [FinishedSession],
        window: TimeInterval = 2 * 60 * 60
    ) -> FinishedSession? {
        let unlinked = sessions.filter { $0.healthLink == nil }
        return unlinked
            .map { session -> (FinishedSession, TimeInterval) in
                (session, abs(session.finishedAt.timeIntervalSince(candidate.endedAt)))
            }
            .filter { $0.1 <= window }
            .sorted { $0.1 < $1.1 }
            .first?
            .0
    }

    /// Workouts already linked to any Foundation session.
    static func linkedWorkoutUUIDs(in sessions: [FinishedSession]) -> Set<UUID> {
        Set(sessions.compactMap(\.healthLink?.workoutUUID))
    }
}
