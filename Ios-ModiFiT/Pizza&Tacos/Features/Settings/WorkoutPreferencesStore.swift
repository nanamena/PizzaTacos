import Foundation
import Combine

struct WorkoutHealthPreference: Codable, Equatable {
    var savesWorkouts = false
    var category: WorkoutActivityCategory?

    var mode: WatchWorkoutHealthMode {
        guard savesWorkouts, let category else { return .withoutAppleHealth }
        return .appleHealth(category)
    }
}

@MainActor
final class WorkoutPreferencesStore: ObservableObject {
    @Published var defaultSets: Int { didSet { persist() } }
    @Published var defaultRepetitions: Int { didSet { persist() } }
    @Published var defaultRestSeconds: Int { didSet { persist() } }

    @Published var health: WorkoutHealthPreference? {
        didSet {
            defaults.set(health.flatMap { try? JSONEncoder().encode($0) }, forKey: healthKey)
        }
    }

    private let healthKey = "modifit.workoutPreferences.appleHealth"
    private let defaults = UserDefaults.standard
    private let keys = [
        "modifit.workoutPreferences.defaultSets",
        "modifit.workoutPreferences.defaultRepetitions",
        "modifit.workoutPreferences.defaultRestSeconds"
    ]

    init() {
        health = defaults.data(forKey: healthKey).flatMap {
            try? JSONDecoder().decode(WorkoutHealthPreference.self, from: $0)
        }
        defaultSets = defaults.object(forKey: keys[0]) as? Int ?? 3
        defaultRepetitions = defaults.object(forKey: keys[1]) as? Int ?? 8
        defaultRestSeconds = defaults.object(forKey: keys[2]) as? Int ?? 60
    }

    private func persist() {
        defaults.set(defaultSets, forKey: keys[0])
        defaults.set(defaultRepetitions, forKey: keys[1])
        defaults.set(defaultRestSeconds, forKey: keys[2])
    }
}
