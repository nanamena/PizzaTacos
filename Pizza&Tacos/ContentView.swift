import SwiftUI

// ContentView enruta las pestañas y comparte los servicios persistentes entre funciones.
struct ContentView: View {
    @State private var selectedTab: AppTab = .workouts
    @StateObject private var viewModel = WorkoutsViewModel()
    @StateObject private var themeStore = AppThemeStore()
    @StateObject private var historyStore = WorkoutHistoryStore()
    @StateObject private var workoutLibrary = WorkoutLibraryStore()
    @StateObject private var workoutPreferences = WorkoutPreferencesStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Workouts", systemImage: "dumbbell.fill", value: AppTab.workouts) {
                WorkoutsView(viewModel: viewModel, historyStore: historyStore, workoutLibrary: workoutLibrary, workoutPreferences: workoutPreferences)
            }
            Tab("Progress", systemImage: "chart.bar.fill", value: AppTab.progress) {
                ProgressView(historyStore: historyStore)
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView(themeStore: themeStore, workoutPreferences: workoutPreferences)
            }
        }
        .id(themeStore.viewIdentity)
        .tint(AppColors.primary)
        .preferredColorScheme(themeStore.preferredColorScheme)
        .sheet(isPresented: $viewModel.isAddWorkoutPresented) {
            AddWorkoutSheet(workoutLibrary: workoutLibrary) {
                viewModel.isManualWorkoutRequested = true
            }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
