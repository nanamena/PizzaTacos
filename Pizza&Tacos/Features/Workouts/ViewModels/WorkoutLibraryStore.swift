import Foundation
import Combine

struct WorkoutPlan: Codable, Identifiable {
    let id: String
    var name: String
    var days: [Routine]
}

private struct SavedWorkoutLibrary: Codable {
    var standaloneRoutines: [Routine] = []
    var sampleRoutines: [Routine] = Routine.samples
    var plan: WorkoutPlan?
    var nextDayIndex = 0
    var isPlanActive = false

    private enum CodingKeys: String, CodingKey {
        case standaloneRoutines, sampleRoutines, plan, nextDayIndex, isPlanActive
    }

    init(standaloneRoutines: [Routine], sampleRoutines: [Routine], plan: WorkoutPlan?, nextDayIndex: Int, isPlanActive: Bool) {
        self.standaloneRoutines = standaloneRoutines
        self.sampleRoutines = sampleRoutines
        self.plan = plan
        self.nextDayIndex = nextDayIndex
        self.isPlanActive = isPlanActive
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        standaloneRoutines = try values.decodeIfPresent([Routine].self, forKey: .standaloneRoutines) ?? []
        sampleRoutines = try values.decodeIfPresent([Routine].self, forKey: .sampleRoutines) ?? Routine.samples
        plan = try values.decodeIfPresent(WorkoutPlan.self, forKey: .plan)
        nextDayIndex = try values.decodeIfPresent(Int.self, forKey: .nextDayIndex) ?? 0
        isPlanActive = try values.decodeIfPresent(Bool.self, forKey: .isPlanActive) ?? false
    }
}

@MainActor
final class WorkoutLibraryStore: ObservableObject {
    struct FeaturedWorkout {
        let routine: Routine
        let planProgressLabel: String?
    }

    @Published private(set) var standaloneRoutines: [Routine] = []
    @Published private(set) var sampleRoutines: [Routine] = Routine.samples
    @Published private(set) var activePlan: WorkoutPlan?
    @Published private(set) var nextDayIndex = 0
    @Published private(set) var isPlanActive = false

    private let storageKey = "modifit.workoutLibrary.v1"
    private let persistenceQueue = DispatchQueue(label: "com.modifit.workout-library-persistence")
    private var hasLocalChanges = false

    init() {
        let storageKey = storageKey
        persistenceQueue.async { [weak self] in
            let data = UserDefaults.standard.data(forKey: storageKey)
            Task { @MainActor [weak self] in
                guard let data,
                      let saved = try? JSONDecoder().decode(SavedWorkoutLibrary.self, from: data) else { return }
                guard let self, !self.hasLocalChanges else { return }
                self.standaloneRoutines = saved.standaloneRoutines
                self.sampleRoutines = saved.sampleRoutines
                self.activePlan = saved.plan
                self.nextDayIndex = saved.nextDayIndex
                self.isPlanActive = saved.isPlanActive
            }
        }
    }

    var featuredWorkout: FeaturedWorkout? {
        if isPlanActive, let activePlan, activePlan.days.indices.contains(nextDayIndex) {
            return FeaturedWorkout(
                routine: activePlan.days[nextDayIndex],
                planProgressLabel: "Day \(nextDayIndex + 1) of \(activePlan.days.count) · \(activePlan.name)"
            )
        }
        return standaloneRoutines.last.map { FeaturedWorkout(routine: $0, planProgressLabel: nil) }
    }

    func saveRoutine(_ routine: Routine) {
        if let index = sampleRoutines.firstIndex(where: { $0.id == routine.id }) {
            sampleRoutines[index] = routine
            persist()
            return
        }
        standaloneRoutines.removeAll { $0.id == routine.id }
        standaloneRoutines.append(routine)
        persist()
    }

    func savePlan(name: String, days: [Routine]) {
        guard !days.isEmpty else { return }
        activePlan = WorkoutPlan(id: UUID().uuidString, name: name, days: days)
        nextDayIndex = 0
        isPlanActive = true
        persist()
    }

    func setPlanActive(_ isActive: Bool) {
        guard activePlan != nil else { return }
        isPlanActive = isActive
        persist()
    }

    func updateRoutine(_ routine: Routine) {
        if let index = sampleRoutines.firstIndex(where: { $0.id == routine.id }) {
            sampleRoutines[index] = routine
            persist()
            return
        }
        guard let index = standaloneRoutines.firstIndex(where: { $0.id == routine.id }) else { return }
        standaloneRoutines[index] = routine
        persist()
    }

    func deleteRoutine(_ routineID: String) {
        standaloneRoutines.removeAll { $0.id == routineID }
        sampleRoutines.removeAll { $0.id == routineID }
        persist()
    }

    func markCompleted(_ routineID: String) {
        guard isPlanActive, let activePlan, activePlan.days.indices.contains(nextDayIndex),
              activePlan.days[nextDayIndex].id == routineID else { return }
        nextDayIndex = (nextDayIndex + 1) % activePlan.days.count
        persist()
    }

    private func persist() {
        let saved = SavedWorkoutLibrary(standaloneRoutines: standaloneRoutines, sampleRoutines: sampleRoutines,
                                        plan: activePlan,
                                        nextDayIndex: nextDayIndex, isPlanActive: isPlanActive)
        let storageKey = storageKey
        hasLocalChanges = true
        guard let data = try? JSONEncoder().encode(saved) else { return }
        persistenceQueue.async {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
