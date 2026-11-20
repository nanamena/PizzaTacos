import Foundation
import Combine

// Este ViewModel guarda la selección de ánimo y la asocia al identificador de una sesión.
@MainActor
final class WorkoutFeedbackViewModel: ObservableObject {
    @Published var selectedFeeling: WorkoutFeeling?
    private let historyStore: WorkoutHistoryStore
    private let workoutID: UUID
    private var hasSaved = false

    init(historyStore: WorkoutHistoryStore, workoutID: UUID) {
        self.historyStore = historyStore
        self.workoutID = workoutID
    }

    func save() {
        guard !hasSaved, let selectedFeeling else { return }
        historyStore.saveFeeling(selectedFeeling, for: workoutID)
        hasSaved = true
    }
}
