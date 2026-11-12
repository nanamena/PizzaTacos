import Foundation
import Observation

struct Workout: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String
    var exerciseCount: Int
    // Display-only estimate. Replace with your exercise-based calculation on integration.
    var estimatedMinutes: Int
    var isFavorite = false
    var createdAt = Date()

    static let samples: [Workout] = [
        Workout(name: "Upper Body", symbol: "dumbbell", exerciseCount: 6, estimatedMinutes: 45, isFavorite: true, createdAt: Date(timeIntervalSince1970: 500)),
        Workout(name: "Lower Body", symbol: "figure.strengthtraining.functional", exerciseCount: 7, estimatedMinutes: 50, createdAt: Date(timeIntervalSince1970: 400)),
        Workout(name: "Core & Mobility", symbol: "figure.cooldown", exerciseCount: 5, estimatedMinutes: 25, isFavorite: true, createdAt: Date(timeIntervalSince1970: 300)),
        Workout(name: "Full Body", symbol: "figure.run", exerciseCount: 8, estimatedMinutes: 55, createdAt: Date(timeIntervalSince1970: 200)),
        Workout(name: "HIIT", symbol: "bolt", exerciseCount: 6, estimatedMinutes: 20, createdAt: Date(timeIntervalSince1970: 100))
    ]
}

@MainActor @Observable
final class WorkoutStore {
    private(set) var workouts: [Workout]
    var storageError: String?
    private let defaults: UserDefaults?
    private let key = "workouts.collection.v1"

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        if let data = defaults?.data(forKey: key) {
            do { workouts = try JSONDecoder().decode([Workout].self, from: data) }
            catch {
                workouts = []
                storageError = "Saved workouts could not be read. The original data has been preserved."
            }
        } else { workouts = Workout.samples }
    }

    func save(_ workout: Workout) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index] = workout
        } else { workouts.append(workout) }
        persist()
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = workouts.firstIndex(where: { $0.id == id }) else { return }
        workouts[index].isFavorite.toggle()
        persist()
    }

    func delete(_ id: UUID) {
        workouts.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        // Do not overwrite unreadable saved data.
        guard storageError == nil else { return }
        do { defaults?.set(try JSONEncoder().encode(workouts), forKey: key) }
        catch { storageError = "Your changes could not be saved." }
    }
}
