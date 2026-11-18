import SwiftUI

struct ExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @FocusState private var nameFocused: Bool
    @State private var exercise: WorkoutExercise
    @State private var baseline: WorkoutExercise
    @State private var discard = false
    let route: ExerciseEditorRoute
    let onCommit: (WorkoutExercise) -> Void

    init(route: ExerciseEditorRoute, onCommit: @escaping (WorkoutExercise) -> Void) {
        self.route = route
        self.onCommit = onCommit
        _exercise = State(initialValue: route.exercise)
        _baseline = State(initialValue: route.exercise)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise name") {
                    TextField("e.g. Bench Press", text: $exercise.name)
                        .accessibilityLabel("Exercise name")
                        .focused($nameFocused)
                }
                Section("Parameters") {
                    WorkoutSetStepper(value: $exercise.sets, range: 1...30)
                    if exercise.isTimed {
                        WorkoutDurationPicker(
                            title: "Duration",
                            value: Binding(get: { exercise.duration ?? 30 }, set: { exercise.duration = $0 }),
                            range: 1...3600
                        )
                    } else {
                        ExerciseNumberField(title: "Repetitions", value: $exercise.reps, range: 1...200)
                    }
                    WorkoutDurationPicker(title: "Rest", value: $exercise.rest, range: 0...600)
                }
                Section {
                    LabeledContent("Estimated duration", value: WorkoutExercise.formatted(exercise.seconds))
                    if route.isNew {
                        Button("Add Another", systemImage: "plus.circle", action: addAnother)
                            .disabled(!exercise.isValid)
                            .frame(minHeight: 44)
                    }
                }
            }
            .font(.system(.body, design: .default))
            .foregroundStyle(.primary)
            .scrollContentBackground(.hidden)
            .background(WorkoutTheme.background(scheme))
            .navigationTitle(route.isNew ? "Add Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                        .confirmationDialog("Discard exercise changes?", isPresented: $discard, titleVisibility: .visible) {
                            Button("Discard Changes", role: .destructive) { dismiss() }
                            Button("Keep Editing", role: .cancel) { }
                        }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                        .buttonStyle(.borderedProminent)
                        .disabled(!exercise.isValid)
                }
            }
        }
        .tint(WorkoutTheme.tint(scheme))
        .interactiveDismissDisabled(exercise != baseline)
    }
    private func cancel() { if exercise != baseline { discard = true } else { dismiss() } }
    private func done() { onCommit(exercise); dismiss() }
    private func addAnother() {
        onCommit(exercise)
        exercise.id = UUID(); exercise.name = ""; baseline = exercise; nameFocused = true
    }
}
