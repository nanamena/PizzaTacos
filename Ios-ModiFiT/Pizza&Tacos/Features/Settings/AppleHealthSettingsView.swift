import SwiftUI

struct AppleHealthSettingsView: View {
    @ObservedObject var preferences: WorkoutPreferencesStore
    var isSetup = false
    var isEmbedded = false

    @Environment(\.appColors) private var appColors
    @ObservedObject private var healthAccess = AppleHealthAccess.shared
    @State private var setupCategory: WorkoutActivityCategory?
    @State private var requestingAccess = false
    @State private var showAccessHelp = false

    private var preference: WorkoutHealthPreference {
        preferences.health ?? WorkoutHealthPreference()
    }

    private var category: Binding<WorkoutActivityCategory?> {
        if isSetup { return $setupCategory }

        return Binding(get: { preference.category }, set: { category in
            var updated = preference
            updated.category = category
            preferences.health = updated
        })
    }

    var body: some View {
        Group {
            if isEmbedded {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Apple Health")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    integrationControls
                    if let explanation {
                        Text(explanation).font(.footnote).foregroundStyle(appColors.secondaryText)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(appColors.text)
                .background(appColors.card, in: RoundedRectangle(cornerRadius: 20))
            } else {
                Form {
                    if isSetup {
                        Section {
                            typePicker.pickerStyle(.navigationLink)
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
                            Text("Connect to save completed workouts. You can change this later in Settings.")
                        }
                    } else {
                        Section {
                            integrationControls
                        } footer: {
                            if let explanation { Text(explanation) }
                        }
                    }
                }
                .navigationTitle("Apple Health")
                .navigationBarTitleDisplayMode(.inline)
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
    }

    @ViewBuilder
    private var integrationControls: some View {
        Toggle("Save Workouts", isOn: Binding(get: { preference.savesWorkouts }, set: setEnabled))
            .toggleStyle(.switch)
            .disabled(!preference.savesWorkouts && (preference.category == nil || !healthAccess.isAvailable))
        if isEmbedded {
            NavigationLink {
                Form { typePicker.pickerStyle(.inline) }
                    .navigationTitle("Default Workout Type")
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                LabeledContent("Default Workout Type") {
                    HStack {
                        if let category = preference.category {
                            Text(category.title)
                        } else {
                            Text("Choose a Type")
                        }
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            typePicker.pickerStyle(.navigationLink)
        }

        if preference.savesWorkouts && healthAccess.isAvailable && !healthAccess.canWriteWorkouts {
            Button("Restore Apple Health Access", action: connect)
        }
    }

    private var explanation: LocalizedStringKey? {
        if !healthAccess.isAvailable { return "Apple Health is unavailable on this device." }
        if preference.category == nil { return "Choose a workout type to enable Apple Health." }
        if preference.savesWorkouts && !healthAccess.canWriteWorkouts {
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
