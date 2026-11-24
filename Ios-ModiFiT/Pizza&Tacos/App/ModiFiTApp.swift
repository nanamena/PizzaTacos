import AppIntents
import SwiftUI

@main
struct ModiFiTApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var historyStore: WorkoutHistoryStore
    @StateObject private var workoutLibrary: WorkoutLibraryStore
    @StateObject private var themeStore = AppThemeStore()
    @StateObject private var workoutPreferences: WorkoutPreferencesStore
    private let watchSync: PhoneWorkoutSync

    init() {
        let history = WorkoutHistoryStore()
        let library = WorkoutLibraryStore()
        _historyStore = StateObject(wrappedValue: history)
        _workoutLibrary = StateObject(wrappedValue: library)
        let preferences = WorkoutPreferencesStore()
        _workoutPreferences = StateObject(wrappedValue: preferences)
        let sync = PhoneWorkoutSync(library: library, history: history, workoutPreferences: preferences)
        watchSync = sync
        let actionHandler: AdvanceWorkoutIntent.ActionHandler = { [weak sync] workoutID, sourceID, revision in
            guard let sync else { return false }
            return await sync.advanceWorkout(workoutID: workoutID, sourceID: sourceID, revision: revision)
        }
        AppDependencyManager.shared.add(key: AdvanceWorkoutIntent.actionDependencyKey, dependency: actionHandler)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(themeStore: themeStore, historyStore: historyStore, workoutLibrary: workoutLibrary, watchSync: watchSync,
                        workoutPreferences: workoutPreferences)
                .task {
                    await AppNotificationAuthorization.requestOnFirstLaunch()
                    await AppleHealthAccess.shared.discardInterruptedWorkoutIfNeeded()
                }
                .onChange(of: themeStore.palette, initial: true) { _, palette in
                    watchSync.updatePalette(palette)
                }
                .onChange(of: workoutPreferences.health) { _, _ in
                    watchSync.syncHealthPreference()
                }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    watchSync.setAppIsActive(phase == .active)
                    if phase == .active {
                        AppleHealthAccess.shared.refresh()
                        watchSync.refresh()
                    }
                }
        }
    }
}
