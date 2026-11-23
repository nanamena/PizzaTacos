import Combine
import Foundation
import OSLog

@MainActor
final class WorkoutHistoryStore: ObservableObject {
    @Published private(set) var records: [WorkoutHistoryRecord] = []
    private let url = WorkoutFiles.location("workout-history.json")
    private let storageKey = "modifit.workoutHistory.v1"
    private let logger = Logger(subsystem: "ModiFiT", category: "WorkoutHistory")
    private var loaded = false

    init() {
        attempt { try loadIfNeeded() }
    }

    func record(_ record: WorkoutHistoryRecord) {
        attempt { try importCompletedWorkout(record) }
    }

    func importCompletedWorkout(_ record: WorkoutHistoryRecord) throws {
        try loadIfNeeded()
        guard !records.contains(where: { $0.id == record.id }) else { return }
        try commit(records + [record])
    }

    func saveFeeling(_ feeling: WorkoutFeeling, for id: UUID) {
        attempt {
            try loadIfNeeded()
            guard let index = records.firstIndex(where: { $0.id == id }) else { return }
            var updated = records
            updated[index].feeling = feeling
            try commit(updated)
        }
    }

    func linkHealthWorkout(_ healthWorkoutID: UUID, to id: UUID) {
        attempt {
            try loadIfNeeded()
            guard let index = records.firstIndex(where: { $0.id == id }) else { return }
            var updated = records
            updated[index].healthWorkoutID = healthWorkoutID
            try commit(updated)
        }
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        do {
            let data = try Data(contentsOf: url)
            records = try JSONDecoder().decode([WorkoutHistoryRecord].self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            if let legacy = UserDefaults.standard.data(forKey: storageKey) {
                let decoded = try JSONDecoder().decode([WorkoutHistoryRecord].self, from: legacy)
                try commit(decoded)
            }
        }
        loaded = true
    }

    private func commit(_ updated: [WorkoutHistoryRecord]) throws {
        try WorkoutFiles.write(updated, to: url)
        records = updated
    }

    private func attempt(_ operation: () throws -> Void) {
        do { try operation() }
        catch { logger.error("Could not read or save workout history.") }
    }
}
