import SwiftUI

@main
struct ModiFiTApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var historyStore: WorkoutHistoryStore
    @StateObject private var workoutLibrary: WorkoutLibraryStore
    @StateObject private var themeStore = AppThemeStore()
    private let watchSync: PhoneWorkoutSync

    init() {
        let history = WorkoutHistoryStore()
        let library = WorkoutLibraryStore()
        _historyStore = StateObject(wrappedValue: history)
        _workoutLibrary = StateObject(wrappedValue: library)
        watchSync = PhoneWorkoutSync(library: library, history: history)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(themeStore: themeStore, historyStore: historyStore, workoutLibrary: workoutLibrary, watchSync: watchSync)
                .task { await AppleHealthAccess.shared.discardInterruptedWorkoutIfNeeded() }
                .onChange(of: themeStore.palette, initial: true) { _, palette in
                    watchSync.updatePalette(palette)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { watchSync.refresh() }
                }
        }
    }
}
