import SwiftUI

// ContentView enruta las pestañas y comparte los servicios persistentes entre funciones.
struct ContentView: View {
    @State private var selectedTab: AppTab = .workouts
    @StateObject private var viewModel = WorkoutsViewModel()
    @ObservedObject var themeStore: AppThemeStore
    @ObservedObject var historyStore: WorkoutHistoryStore
    @ObservedObject var workoutLibrary: WorkoutLibraryStore
    @ObservedObject var watchSync: PhoneWorkoutSync
    @StateObject private var workoutPreferences = WorkoutPreferencesStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Workouts", systemImage: "dumbbell.fill", value: AppTab.workouts) {
                WorkoutsView(viewModel: viewModel, historyStore: historyStore, workoutLibrary: workoutLibrary, workoutPreferences: workoutPreferences, watchSync: watchSync)
            }
            Tab("Progress", systemImage: "chart.bar.fill", value: AppTab.progress) {
                ProgressView(historyStore: historyStore)
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView(themeStore: themeStore, workoutPreferences: workoutPreferences)
            }
        }
        .sheet(isPresented: $viewModel.isAddWorkoutPresented, onDismiss: {
            selectedTab = .workouts
            viewModel.presentPreparedImport()
        }) {
            AddWorkoutSheet(startAtScanner: viewModel.startAtScanner,
                            onImportReady: viewModel.prepareImportedWorkout) {
                viewModel.isManualWorkoutRequested = true
            }
                .id(viewModel.addWorkoutPresentationID)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .modifier(AppTheme(palette: themeStore.palette))
        .preferredColorScheme(nil)
        .onChange(of: watchSync.pendingWatchExerciseSelectionRequest?.id, initial: true) { _, requestID in
            if requestID != nil { selectedTab = .workouts }
        }
    }
}
