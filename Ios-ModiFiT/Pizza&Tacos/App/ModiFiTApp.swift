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
        watchSync = PhoneWorkoutSync(library: library, history: history, workoutPreferences: preferences)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(themeStore: themeStore, historyStore: historyStore, workoutLibrary: workoutLibrary, watchSync: watchSync,
                        workoutPreferences: workoutPreferences)
                .task { await AppleHealthAccess.shared.discardInterruptedWorkoutIfNeeded() }
                .onChange(of: themeStore.palette, initial: true) { _, palette in
                    watchSync.updatePalette(palette)
                }
                .onChange(of: workoutPreferences.health) { _, _ in
                    watchSync.syncHealthPreference()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        AppleHealthAccess.shared.refresh()
                        watchSync.refresh()
                    }
                }
        }
    }
}
