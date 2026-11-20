import Foundation
import Combine

// Este almacén conserva sesiones finalizadas y comentarios de ánimo en almacenamiento local.
@MainActor
final class WorkoutHistoryStore: ObservableObject {
    @Published private(set) var records: [WorkoutHistoryRecord] = []
    private let storageKey = "modifit.workoutHistory.v1"
    private let persistenceQueue = DispatchQueue(label: "com.modifit.workout-history-persistence")
    private var hasLocalChanges = false

    init() {
        let storageKey = storageKey
        persistenceQueue.async { [weak self] in
            guard let data = UserDefaults.standard.data(forKey: storageKey),
                  let decoded = try? JSONDecoder().decode([WorkoutHistoryRecord].self, from: data) else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.hasLocalChanges else { return }
                self.records = decoded
            }
        }
    }

    // Registra una sesión finalizada y evita duplicarla si se recibe dos veces el mismo identificador.
    func record(_ record: WorkoutHistoryRecord) {
        guard !records.contains(where: { $0.id == record.id }) else { return }
        records.append(record)
        hasLocalChanges = true
        persist()
    }

    // Añade o reemplaza el ánimo asociado a una sesión ya finalizada.
    func saveFeeling(_ feeling: WorkoutFeeling, for id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].feeling = feeling
        hasLocalChanges = true
        persist()
    }

    func linkHealthWorkout(_ healthWorkoutID: UUID, to id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].healthWorkoutID = healthWorkoutID
        hasLocalChanges = true
        persist()
    }

    private func persist() {
        let records = records
        let storageKey = storageKey
        persistenceQueue.async {
            guard let data = try? JSONEncoder().encode(records) else { return }
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
