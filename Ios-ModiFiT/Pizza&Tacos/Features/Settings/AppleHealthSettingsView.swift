import SwiftUI

struct AppleHealthSettingsView: View {
    @ObservedObject var preferences: WorkoutPreferencesStore
    var isSetup = false

    @Environment(\.appColors) private var appColors
    @ObservedObject private var healthAccess = AppleHealthAccess.shared
    @State private var setupCategory: WorkoutActivityCategory?
    @State private var requestingAccess = false
    @State private var showAccessHelp = false

    private var preference: WorkoutHealthPreference {
        preferences.health ?? WorkoutHealthPreference()
    }

    private var savesWorkouts: Bool {
        preference.category != nil && preference.savesWorkouts
    }

    private var category: Binding<WorkoutActivityCategory?> {
        if isSetup { return $setupCategory }

        return Binding(get: { preference.category }, set: { category in
            preferences.health = WorkoutHealthPreference(
                savesWorkouts: savesWorkouts && category != nil,
                category: category
            )
        })
    }

    var body: some View {
        Group {
            if isSetup {
                Form {
                    Section {
                        typePicker
                    } footer: {
                        Text("This type is used for workouts started on iPhone and Apple Watch.")
                    }
                    Section {
                        Button("Connect Apple Health", action: connect)
                            .disabled(setupCategory == nil || !healthAccess.isAvailable)
                        Button("Continue Without Apple Health") {
                            preferences.health = WorkoutHealthPreference(category: setupCategory)
                        }
                    } footer: {
                        Text("Connect to save completed workouts. You can change this later in Settings under Workout Preferences.")
                    }
                }
                .navigationTitle("Apple Health")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Section {
                    typePicker
                    Toggle("Save Workouts", isOn: Binding(get: { savesWorkouts }, set: setEnabled))
                        .disabled(preference.category == nil || (!savesWorkouts && !healthAccess.isAvailable))

                    if savesWorkouts && healthAccess.isAvailable && !healthAccess.canWriteWorkouts {
                        Button("Restore Apple Health Access", action: connect)
                    }
                } header: {
                    Text("Apple Health")
                        .foregroundStyle(appColors.secondaryText)
                } footer: {
                    Text(explanation)
                        .foregroundStyle(appColors.secondaryText)
                }
            }
        }
        .disabled(requestingAccess)
        .task { healthAccess.refresh() }
        .alert("Apple Health Access", isPresented: $showAccessHelp) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Open the Health app and review ModiFiT’s workout permissions.")
        }
    }

    private var typePicker: some View {
        Picker("Default Workout Type", selection: category) {
            if category.wrappedValue == nil {
                Text("Choose a Type").tag(nil as WorkoutActivityCategory?)
            }
            ForEach(WorkoutActivityCategory.allCases) { category in
                Text(category.title).tag(Optional(category))
            }
        }
        .pickerStyle(.navigationLink)
    }

    private var explanation: LocalizedStringKey {
        if !healthAccess.isAvailable { return "Apple Health is unavailable on this device." }
        if preference.category == nil { return "Choose a workout type to enable Save Workouts." }
        if savesWorkouts && !healthAccess.canWriteWorkouts {
            return "ModiFiT needs permission to save workouts on this iPhone."
        }
        return "Changes apply to your next workout on iPhone or Apple Watch."
    }

    private func setEnabled(_ enabled: Bool) {
        if enabled {
            connect()
        } else {
            var updated = preference
            updated.savesWorkouts = false
            preferences.health = updated
        }
    }

    private func connect() {
        guard !requestingAccess, let selectedCategory = category.wrappedValue else { return }
        requestingAccess = true
        Task {
            defer { requestingAccess = false }
            guard await healthAccess.requestAccess() else {
                showAccessHelp = true
                return
            }
            preferences.health = WorkoutHealthPreference(savesWorkouts: true, category: selectedCategory)
        }
    }
}
