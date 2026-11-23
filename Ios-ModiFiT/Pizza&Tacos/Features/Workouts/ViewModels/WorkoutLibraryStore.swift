import Foundation
import Combine

private struct LegacyWorkoutPlan: Decodable {
    let days: [Routine]
}

private struct SavedWorkoutLibrary: Codable {
    var standaloneRoutines: [Routine] = []

    private enum CodingKeys: String, CodingKey {
        case standaloneRoutines, plan
    }

    init(standaloneRoutines: [Routine]) {
        self.standaloneRoutines = standaloneRoutines
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        standaloneRoutines = try values.decodeIfPresent([Routine].self, forKey: .standaloneRoutines) ?? []
        if let legacyPlan = try values.decodeIfPresent(LegacyWorkoutPlan.self, forKey: .plan) {
            let existingIDs = Set(standaloneRoutines.map(\.id))
            standaloneRoutines.append(contentsOf: legacyPlan.days.filter { !existingIDs.contains($0.id) })
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(standaloneRoutines, forKey: .standaloneRoutines)
    }
}

@MainActor
final class WorkoutLibraryStore: ObservableObject {
    struct FeaturedWorkout {
        let routine: Routine
    }

    @Published private(set) var standaloneRoutines: [Routine] = []

    private let storageKey = "modifit.workoutLibrary.v1"
    private let persistenceQueue = DispatchQueue(label: "com.modifit.workout-library-persistence")
    let catalogDidChange = PassthroughSubject<Void, Never>()

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(SavedWorkoutLibrary.self, from: data) {
            standaloneRoutines = saved.standaloneRoutines
            persist()
        }
    }

    var featuredWorkout: FeaturedWorkout? {
        standaloneRoutines.last.map { FeaturedWorkout(routine: $0) }
    }

    func saveRoutine(_ routine: Routine) {
        saveRoutines([routine])
    }

    func saveRoutines(_ routines: [Routine]) {
        guard !routines.isEmpty else { return }
        for routine in routines {
            standaloneRoutines.removeAll { $0.id == routine.id }
            standaloneRoutines.append(routine)
        }
        persist()
    }

    func updateRoutine(_ routine: Routine) {
        guard let index = standaloneRoutines.firstIndex(where: { $0.id == routine.id }) else { return }
        standaloneRoutines[index] = routine
        persist()
    }

    func deleteRoutine(_ routineID: String) {
        standaloneRoutines.removeAll { $0.id == routineID }
        persist()
    }

    private func persist() {
        let saved = SavedWorkoutLibrary(standaloneRoutines: standaloneRoutines)
        let storageKey = storageKey
        guard let data = try? JSONEncoder().encode(saved) else { return }
        persistenceQueue.async {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        catalogDidChange.send()
    }
}
