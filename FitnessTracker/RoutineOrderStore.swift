import Foundation
import Observation

/// Persists Home My Routines display order (shipping + custom ids).
@Observable
final class RoutineOrderStore {
    private static let defaultsKey = "foundation.routineOrder.v1"
    private(set) var orderedIDs: [String]

    init() {
        orderedIDs = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
    }

    /// Merges saved order with current routines; new ids append at the end.
    func ordered(shipping: [Routine], customs: [Routine]) -> [Routine] {
        let catalog = shipping + customs
        let byID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        var seen = Set<String>()
        var result: [Routine] = []

        for id in orderedIDs {
            guard let routine = byID[id], seen.insert(id).inserted else { continue }
            result.append(routine)
        }
        for routine in catalog where seen.insert(routine.id).inserted {
            result.append(routine)
        }
        return result
    }

    func save(_ ids: [String]) {
        orderedIDs = ids
        UserDefaults.standard.set(ids, forKey: Self.defaultsKey)
    }

    func remove(id: String) {
        guard orderedIDs.contains(id) else { return }
        orderedIDs.removeAll { $0 == id }
        UserDefaults.standard.set(orderedIDs, forKey: Self.defaultsKey)
    }
}
