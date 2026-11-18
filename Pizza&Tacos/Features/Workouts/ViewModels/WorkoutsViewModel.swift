import SwiftUI
import Combine

// Este ViewModel administra el encabezado, las rutinas y las interacciones de Workouts.
@MainActor
final class WorkoutsViewModel: ObservableObject {
    @Published var selectedTab: AppTab = .workouts
    @Published var isAddWorkoutPresented = false
    @Published var selectedRoutine: Routine?
    @Published var activeWorkout: Routine?

    let userName = "Linda"
    let todayWorkout = TodayWorkout(name: "Upper Body", exerciseCount: 5, estimatedMinutes: 28)

    // Estos datos de ejemplo reproducen el contenido visual de referencia mientras se integra el almacenamiento.
    let routines = [
        Routine(id: "upper", name: "Upper Body", exerciseCount: 6, estimatedMinutes: 45, symbol: "dumbbell") ,
        Routine(id: "lower", name: "Lower Body", exerciseCount: 5, estimatedMinutes: 35, symbol: "figure.walk") ,
        Routine(id: "full", name: "Full Body", exerciseCount: 8, estimatedMinutes: 55, symbol: "figure.strengthtraining.traditional")
    ]

    // Esta función muestra el menú para importar o crear una rutina.
    func presentAddWorkout() {
        isAddWorkoutPresented = true
    }

    // Esta función presenta los detalles básicos de la rutina seleccionada.
    func select(_ routine: Routine) {
        selectedRoutine = routine
    }

    // Esta función cambia de pestaña y anima el indicador seleccionado.
    func select(_ tab: AppTab) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = tab
        }
    }
}
