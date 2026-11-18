import Foundation
import Combine

struct WorkoutPlan: Codable, Identifiable {
    let id: String
    var name: String
    var days: [Routine]
}

private struct SavedWorkoutLibrary: Codable {
    var standaloneRoutines: [Routine] = []
    var plan: WorkoutPlan?
    var nextDayIndex = 0
    var pendingRoutineID: String?
}

@MainActor
final class WorkoutLibraryStore: ObservableObject {
    @Published private(set) var standaloneRoutines: [Routine] = []
    @Published private(set) var activePlan: WorkoutPlan?
    @Published private(set) var nextDayIndex = 0
    @Published private(set) var pendingRoutineID: String?

    private let storageKey = "modifit.workoutLibrary.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(SavedWorkoutLibrary.self, from: data) else { return }
        standaloneRoutines = saved.standaloneRoutines
        activePlan = saved.plan
        nextDayIndex = saved.nextDayIndex
        pendingRoutineID = saved.pendingRoutineID
    }

    var nextRoutine: Routine? {
        if let activePlan, activePlan.days.indices.contains(nextDayIndex) {
            return activePlan.days[nextDayIndex]
        }
        return standaloneRoutines.first { $0.id == pendingRoutineID }
    }

    var nextWorkoutLabel: String? {
        guard let activePlan, activePlan.days.indices.contains(nextDayIndex) else { return nil }
        return "Day \(nextDayIndex + 1) of \(activePlan.days.count) · \(activePlan.name)"
    }

    func saveRoutine(_ routine: Routine) {
        standaloneRoutines.removeAll { $0.id == routine.id }
        standaloneRoutines.append(routine)
        pendingRoutineID = routine.id
        persist()
    }

    func savePlan(name: String, days: [Routine]) {
        guard !days.isEmpty else { return }
        activePlan = WorkoutPlan(id: UUID().uuidString, name: name, days: days)
        nextDayIndex = 0
        pendingRoutineID = nil
        persist()
    }

    func markCompleted(_ routineID: String) {
        if let activePlan, activePlan.days.indices.contains(nextDayIndex), activePlan.days[nextDayIndex].id == routineID {
            nextDayIndex = (nextDayIndex + 1) % activePlan.days.count
        } else if pendingRoutineID == routineID {
            pendingRoutineID = nil
        }
        persist()
    }

    private func persist() {
        let saved = SavedWorkoutLibrary(standaloneRoutines: standaloneRoutines, plan: activePlan,
                                        nextDayIndex: nextDayIndex, pendingRoutineID: pendingRoutineID)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
