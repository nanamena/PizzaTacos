import SwiftUI

struct CreateWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var name: String
    @State private var exercises: [WorkoutExercise]
    @State private var editor: ExerciseEditorRoute?
    @State private var confirmDiscard = false
    @FocusState private var nameFocused: Bool
    private let initialName: String
    private let initialExercises: [WorkoutExercise]
    private let isEditing: Bool
    private let defaultSets: Int
    private let defaultRepetitions: Int
    private let defaultRestSeconds: Int
    private let onSave: (String, [WorkoutExercise]) -> Void

    @MainActor init(routine: Routine? = nil, defaultSets: Int = 3, defaultRepetitions: Int = 10,
         defaultRestSeconds: Int = 60,
         onSave: @escaping (String, [WorkoutExercise]) -> Void) {
        let name = routine?.name ?? ""
        let exercises = routine?.exercises.map(WorkoutExercise.init) ?? []
        _name = State(initialValue: name)
        _exercises = State(initialValue: exercises)
        initialName = name
        initialExercises = exercises
        isEditing = routine != nil
        self.defaultSets = defaultSets
        self.defaultRepetitions = defaultRepetitions
        self.defaultRestSeconds = defaultRestSeconds
        self.onSave = onSave
    }

    private var isDirty: Bool { name != initialName || exercises != initialExercises }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !exercises.isEmpty && exercises.allSatisfy(\.isValid) }

    var body: some View {
        List {
            Section("Workout Name") {
                TextField("e.g. Upper Body", text: $name)
                    .accessibilityLabel("Workout name")
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { nameFocused = false }
                }
            Section("Exercises") {
                if exercises.isEmpty {
                    ContentUnavailableView("No exercises yet", systemImage: "dumbbell", description: Text("Add the exercises from your routine."))
                }
                ForEach(exercises) { exercise in
                    HStack {
                        Button { openEditor(exercise) } label: {
                            WorkoutExerciseRow(exercise: exercise)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edit exercise")
                    }
                    .draggable(exercise.id.uuidString) {
                        WorkoutExerciseRow(exercise: exercise)
                    }
                    .dropDestination(for: String.self) { draggedIDs, location in
                        guard let draggedID = draggedIDs.first,
                              let draggedUUID = UUID(uuidString: draggedID) else { return false }
                        moveExercise(draggedUUID, to: exercise.id, after: location.y > 30)
                        return true
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            remove(exercise)
                        }
                    }
                }
                Button("Add Exercise", systemImage: "plus.circle.fill", action: addExercise)
                    .frame(minHeight: 44)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(WorkoutTheme.background(scheme))
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            WorkoutSummaryView(exercises: exercises)
                .padding(.horizontal)
                .padding(.vertical, 10)
        }
        .navigationTitle(isEditing ? "Edit Workout" : "Create Workout")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                        .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                            Button("Discard Changes", role: .destructive) { dismiss() }
                            Button("Keep Editing", role: .cancel) { }
                        }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
        }
        .sheet(item: $editor) { route in
            ExerciseEditorView(route: route, onCommit: commit)
        }
        .tint(WorkoutTheme.tint(scheme))
        .interactiveDismissDisabled(isDirty)
    }

    private func addExercise() {
        nameFocused = false
        editor = .init(exercise: WorkoutExercise(sets: defaultSets, reps: defaultRepetitions, rest: defaultRestSeconds), isNew: true)
    }
    private func openEditor(_ exercise: WorkoutExercise) { nameFocused = false; editor = .init(exercise: exercise, isNew: false) }
    private func duplicate(_ exercise: WorkoutExercise) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        var copy = exercise; copy.id = UUID(); copy.sourceID = nil; exercises.insert(copy, at: index + 1)
    }
    private func moveExercise(_ draggedID: UUID, to targetID: UUID, after: Bool) {
        guard let sourceIndex = exercises.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = exercises.firstIndex(where: { $0.id == targetID }),
              draggedID != targetID else { return }

        withAnimation(.snappy) {
            var destinationIndex = targetIndex + (after ? 1 : 0)
            let draggedExercise = exercises.remove(at: sourceIndex)
            if sourceIndex < destinationIndex { destinationIndex -= 1 }
            destinationIndex = min(destinationIndex, exercises.count)
            exercises.insert(draggedExercise, at: destinationIndex)
        }
    }
    private func remove(_ exercise: WorkoutExercise) { exercises.removeAll { $0.id == exercise.id } }
    private func commit(_ exercise: WorkoutExercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) { exercises[index] = exercise }
        else { exercises.append(exercise) }
    }
    private func cancel() { if isDirty { confirmDiscard = true } else { dismiss() } }
    private func save() { onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), exercises); dismiss() }
}

