import SwiftUI

// ContentView enruta las pestañas y comparte los servicios persistentes entre funciones.
struct ContentView: View {
    @StateObject private var viewModel = WorkoutsViewModel()
    @StateObject private var themeStore = AppThemeStore()
    @StateObject private var profileStore = UserProfileStore()
    @StateObject private var historyStore = WorkoutHistoryStore()

    var body: some View {
        Group {
            switch viewModel.selectedTab {
            case .workouts:
                WorkoutsView(viewModel: viewModel)
            case .progress:
                ProgressView(historyStore: historyStore, selectedTab: $viewModel.selectedTab)
            case .settings:
                SettingsView(themeStore: themeStore, profileStore: profileStore, selectedTab: $viewModel.selectedTab)
            }
        }
        .id(themeStore.viewIdentity)
        .tint(AppColors.primary)
        .preferredColorScheme(themeStore.preferredColorScheme)
        .sheet(isPresented: $viewModel.isAddWorkoutPresented) {
            AddWorkoutSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $viewModel.selectedRoutine) { routine in
            RoutineDetailSheet(routine: routine, activeWorkout: $viewModel.activeWorkout, historyStore: historyStore)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}
