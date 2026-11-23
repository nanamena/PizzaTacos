import SwiftUI

struct WatchWorkoutView: View {
    let model: WatchWorkoutModel
    @Environment(\.appColors) private var colors
    @State private var confirmsDiscard = false

    var body: some View {
        NavigationStack {
            Group {
                if let active = model.active {
                    WatchActiveWorkoutView(active: active, model: model) {
                        confirmsDiscard = true
                    }
                } else if model.showingResult, let result = model.result {
                    summary(result)
                } else {
                    catalog
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(model.active == nil && !model.showingResult ? "Routines" : "ModiFiT")
        }
        .confirmationDialog("End this workout?", isPresented: $confirmsDiscard) {
            Button("Discard Workout", role: .destructive) { model.discard() }
        } message: {
            Text("Your progress in this workout will be discarded.")
        }
        .alert("ModiFiT", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: {
            Text(model.error ?? "")
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

            if let result = model.result {
                NavigationLink("Last Workout") { summary(result, showDone: false) }
                    .listRowBackground(catalogRowBackground)
            }

            Section("Apple Health") {
                if model.healthAvailable {
                    Button(model.savesToHealth ? "Stop Saving Workouts" : "Connect Apple Health") {
                        Task { await model.setHealthEnabled(!model.savesToHealth) }
                    }
                    .disabled(model.authorizingHealth)
                    .listRowBackground(catalogRowBackground)
                } else {
                    Text("Apple Health unavailable")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.elliptical)
    }

    private var catalogRowBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.fill.tertiary)
    }

    private func summary(_ result: WatchWorkoutResult, showDone: Bool = true) -> some View {
        List {
            Section("Workout Complete") {
                Text(result.record.routineName).font(.headline)
                Text(Duration.seconds(result.record.durationSeconds), format: .time(pattern: .minuteSecond)).monospacedDigit()
            }
            .listRowBackground(colors.surface)
            Section("Apple Health") {
                switch result.health {
                case .off: Text("Saving off for this workout")
                case .saving, .recording: Text("Saving…")
                case .saved: Label("Saved", systemImage: "checkmark.circle")
                case .failed: Text("Couldn’t save to Apple Health")
                }
                if result.record.id == model.result?.record.id, let energy = model.resultEnergy {
                    Text("\(energy.formatted(.number.precision(.fractionLength(0)))) kcal active energy")
                }
            }
            .listRowBackground(colors.surface)
            Section("iPhone") {
                Text(result.synced ? "Synced" : "Waiting to sync")
            }
            .listRowBackground(colors.surface)
            if showDone {
                Button("Done", action: model.dismissResult)
                    .buttonStyle(WatchActionStyle())
                    .listRowBackground(Color.clear)
            }
        }
        .foregroundStyle(colors.text)
    }
}
