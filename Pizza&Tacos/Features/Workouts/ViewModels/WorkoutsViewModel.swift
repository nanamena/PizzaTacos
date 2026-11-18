import Combine

// Este ViewModel administra el encabezado, las rutinas y las interacciones de Workouts.
@MainActor
final class WorkoutsViewModel: ObservableObject {
    @Published var isAddWorkoutPresented = false
    let todayWorkout = TodayWorkout(name: "Upper Body", exerciseCount: 5, estimatedMinutes: 28)

    let routines = Routine.samples

    // Esta función muestra el menú para importar o crear una rutina.
    func presentAddWorkout() {
        isAddWorkoutPresented = true
    }
}
