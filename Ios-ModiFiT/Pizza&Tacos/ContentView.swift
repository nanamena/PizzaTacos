import SwiftUI

// ContentView enruta las pestañas y comparte los servicios persistentes entre funciones.
struct ContentView: View {
    @State private var selectedTab: AppTab = .workouts
    @StateObject private var viewModel = WorkoutsViewModel()
    @ObservedObject var themeStore: AppThemeStore
    @ObservedObject var historyStore: WorkoutHistoryStore
    @ObservedObject var workoutLibrary: WorkoutLibraryStore
    @ObservedObject var watchSync: PhoneWorkoutSync
    @ObservedObject var workoutPreferences: WorkoutPreferencesStore
    @State private var hiddenWatchWorkout: UUID?

    private enum WorkoutPresentation: Identifiable {
        case phone(UUID), watch(UUID)

        var id: UUID {
            switch self {
            case .phone(let id), .watch(let id): id
            }
        }
    }

    private var workoutPresentation: WorkoutPresentation? {
        if let workout = watchSync.phoneWorkout { return .phone(workout.workoutID) }
        if let workout = watchSync.live.remoteWorkout, !viewModel.isAddWorkoutPresented,
           hiddenWatchWorkout != workout.id || watchSync.live.isConnected {
            return .watch(workout.id)
        }
        return nil
    }

    var body: some View {
        let presentation = workoutPresentation
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
        .sheet(isPresented: Binding(get: {
            workoutPreferences.health == nil && presentation == nil && !viewModel.isAddWorkoutPresented
                && watchSync.pendingWatchExerciseSelectionRequest == nil
        }, set: { _ in })) {
            NavigationStack {
                AppleHealthSettingsView(preferences: workoutPreferences, isSetup: true)
            }
            .interactiveDismissDisabled()
        }
        .fullScreenCover(item: Binding(get: { presentation }, set: { _ in })) { route in
            PresentedWorkout(route: route, watchSync: watchSync, historyStore: historyStore) { id in
                hiddenWatchWorkout = id
                selectedTab = .workouts
            }
            .interactiveDismissDisabled()
        }
        .onChange(of: watchSync.live.isConnected) { _, connected in
            if connected { hiddenWatchWorkout = nil }
        }
        .alert("Workout Couldn’t Start", isPresented: Binding(
            get: { watchSync.workoutStartIssue && presentation == nil },
            set: { if !$0 { watchSync.hideWorkoutStartIssue() } }
        )) {
            Button("Try Again") {
                Task { @MainActor in
                    await Task.yield()
                    watchSync.retryWorkoutStart()
                }
            }
            Button("Cancel", role: .cancel) { watchSync.dismissWorkoutStartIssue() }
        } message: {
            Text("Open ModiFiT on Apple Watch, then try again.")
        }
        .modifier(AppTheme(palette: themeStore.palette))
        .preferredColorScheme(nil)
        .onChange(of: watchSync.pendingWatchExerciseSelectionRequest?.id, initial: true) { _, requestID in
            if requestID != nil { selectedTab = .workouts }
        }
    }

    private struct PresentedWorkout: View {
        let route: WorkoutPresentation
        @ObservedObject var watchSync: PhoneWorkoutSync
        let historyStore: WorkoutHistoryStore
        let hideWatchWorkout: (UUID) -> Void

        var body: some View {
            NavigationStack {
                switch route {
                case .phone:
                    if let workout = watchSync.phoneWorkout {
                        FocusWorkoutView(viewModel: workout, historyStore: historyStore, liveLink: watchSync.live,
                                         onFinish: watchSync.dismissPhoneWorkout)
                    }
                case .watch(let id):
                    if let workout = watchSync.live.remoteWorkout, workout.id == id {
                        WatchMirroredFocusWorkoutView(workout: workout, link: watchSync.live) {
                            hideWatchWorkout(id)
                        }
                    }
                }
            }
        }
    }
}
