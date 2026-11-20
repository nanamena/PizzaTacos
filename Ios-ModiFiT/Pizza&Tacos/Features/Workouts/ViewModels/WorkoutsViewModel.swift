import Combine
import Foundation

struct ImportedWorkoutRequest: Identifiable, Hashable {
    let id = UUID()
    let draft: WorkoutImportDraft

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// Este ViewModel administra el encabezado, las rutinas y las interacciones de Workouts.
@MainActor
final class WorkoutsViewModel: ObservableObject {
    @Published var isAddWorkoutPresented = false
    @Published var isManualWorkoutRequested = false
    @Published var importedWorkout: ImportedWorkoutRequest?
    @Published private(set) var startAtScanner = false
    @Published private(set) var addWorkoutPresentationID = UUID()
    private var pendingImportedWorkout: ImportedWorkoutRequest?
    private var returnToScanner = false

    // Esta función muestra el menú para importar o crear una rutina.
    func presentAddWorkout() {
        startAtScanner = false
        addWorkoutPresentationID = UUID()
        isAddWorkoutPresented = true
    }

    func prepareImportedWorkout(_ draft: WorkoutImportDraft) {
        pendingImportedWorkout = ImportedWorkoutRequest(draft: draft)
    }

    func presentPreparedImport() {
        guard let pendingImportedWorkout else { return }
        self.pendingImportedWorkout = nil
        startAtScanner = false
        importedWorkout = pendingImportedWorkout
    }

    func requestReturnToScanner() { returnToScanner = true }

    func reopenScannerIfRequested() {
        guard returnToScanner else { return }
        returnToScanner = false
        startAtScanner = true
        addWorkoutPresentationID = UUID()
        isAddWorkoutPresented = true
    }
}
