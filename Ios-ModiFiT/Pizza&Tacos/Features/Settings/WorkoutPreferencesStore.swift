import Foundation
import Combine

@MainActor
final class WorkoutPreferencesStore: ObservableObject {
    @Published var defaultSets: Int { didSet { persist() } }
    @Published var defaultRepetitions: Int { didSet { persist() } }
    @Published var defaultRestSeconds: Int { didSet { persist() } }

    private let defaults = UserDefaults.standard
    private let keys = [
        "modifit.workoutPreferences.defaultSets",
        "modifit.workoutPreferences.defaultRepetitions",
        "modifit.workoutPreferences.defaultRestSeconds"
    ]

    init() {
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
