import SwiftUI

struct WatchWorkoutView: View {
    let model: WatchWorkoutModel
    let live: LiveWorkoutLink
    @State private var hiddenPhoneWorkout: UUID?

    var body: some View {
        Group {
            if model.active == nil, !model.showingResult, let workout = live.remoteWorkout,
               hiddenPhoneWorkout != workout.id || live.isConnected {
                mirroredWorkout(workout)
            } else {
                localWorkoutNavigation
            }
        }
        .onChange(of: live.isConnected) { _, connected in
            if connected { hiddenPhoneWorkout = nil }
        }
    }

    private var localWorkoutNavigation: some View {
        NavigationStack {
            Group {
                if let active = model.active {
                    WatchActiveWorkoutView(workout: active.liveWorkout, actionsEnabled: !model.busy,
                                           hasConflict: live.hasConflict, healthFailed: active.health == .failed,
                                           onAction: model.applyLiveWorkoutAction)
                        .id(active.id)
                        .navigationTitle("ModiFiT")
                } else if model.showingResult, let result = model.result {
                    WatchWorkoutSummaryView(result: result, activeEnergy: model.resultEnergy, onDone: model.dismissResult)
                } else {
                    catalog.navigationTitle("Routines")
                }
            }
            .background(Color.black.ignoresSafeArea())
        }
        .alert("ModiFiT", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: {
            Text(model.error ?? "")
        }
    }

    private func mirroredWorkout(_ workout: LiveWorkoutSnapshot) -> some View {
        let deadline = workout.pausedAt == nil && !workout.resting ? workout.deadline : nil
        return WatchActiveWorkoutView(
            workout: workout,
            actionsEnabled: live.isConnected && !live.commandPending,
            isConnected: live.isConnected,
            commandRejected: live.commandRejected,
            onBrowseRoutines: { hiddenPhoneWorkout = workout.id },
            onAction: { live.sendAction($0, for: workout.id) }
        )
        .id(workout.id)
        .task(id: deadline) {
            guard let deadline else { return }
            do {
                try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
                live.refreshRemoteWorkout()
            } catch {
                // A newer set or a pause superseded this deadline.
            }
        }
    }

    private var catalog: some View {
        List {
            if model.routines.isEmpty {
                Group {
                    if model.hasCatalog {
                        ContentUnavailableView("No Routines", systemImage: "list.bullet", description: Text("Create a routine in ModiFiT on iPhone."))
                    } else {
                        ContentUnavailableView("Sync Your Routines", systemImage: "iphone", description: Text("Open ModiFiT on your iPhone to sync routines."))
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            ForEach(model.routines) { routine in
                NavigationLink {
                    WatchRoutineView(model: model, routine: routine)
                } label: {
                    WatchRoutineRow(routine: routine)
                }
                .listRowBackground(catalogRowBackground)
            }
        }
        .listStyle(.elliptical)
    }

    private var catalogRowBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.fill.tertiary)
    }
}
