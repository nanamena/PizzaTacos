import SwiftUI

struct WatchRoutineView: View {
    let model: WatchWorkoutModel
    let routine: Routine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let currentRoutine = model.routines.first { $0.id == routine.id }
        List {
            if let currentRoutine, !currentRoutine.exercises.isEmpty {
                Button(model.startNeedsRetry ? "Try Again" : "Start") {
                    Task { await model.start(routineID: currentRoutine.id) { dismiss() } }
                }
                .accessibilityLabel(model.startNeedsRetry ? "Retry Workout Start" : "Start Workout")
                .buttonStyle(WatchActionStyle(kind: .start))
                .listRowBackground(Color.clear)
                .disabled(model.busy)
                if model.startNeedsRetry {
                    Text("Connect to ModiFiT on iPhone to start.")
                        .font(.footnote)
                    Button("Cancel", role: .cancel) { model.cancelPendingStart() }
                }
            } else {
                Text(currentRoutine == nil ? "This routine is no longer available." : "This routine has no exercises.")
            }
        }
        .onDisappear { model.cancelPendingStart() }
        .listStyle(.elliptical)
        .navigationTitle(currentRoutine?.name ?? routine.name)
    }
}
