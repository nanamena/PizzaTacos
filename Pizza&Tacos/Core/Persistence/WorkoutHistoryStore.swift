import Foundation
import Combine

// Este almacén conserva sesiones finalizadas y comentarios de ánimo en almacenamiento local.
@MainActor
final class WorkoutHistoryStore: ObservableObject {
    @Published private(set) var records: [WorkoutHistoryRecord] = []
    private let storageKey = "modifit.workoutHistory.v1"

    init() { load() }

    // Registra una sesión finalizada y evita duplicarla si se recibe dos veces el mismo identificador.
    func record(_ record: WorkoutHistoryRecord) {
        guard !records.contains(where: { $0.id == record.id }) else { return }
        records.append(record)
        persist()
    }

    // Añade o reemplaza el ánimo asociado a una sesión ya finalizada.
    func saveFeeling(_ feeling: WorkoutFeeling, for id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].feeling = feeling
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WorkoutHistoryRecord].self, from: data) else { return }
        records = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
