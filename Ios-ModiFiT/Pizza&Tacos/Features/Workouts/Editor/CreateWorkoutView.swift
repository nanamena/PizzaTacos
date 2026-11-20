import SwiftUI

struct CreateWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appColors) private var appColors
    @State private var name: String
    @State private var exercises: [WorkoutExercise]
    @State private var editor: ExerciseEditorRoute?
    @State private var confirmDiscard = false
    @State private var importDraft: WorkoutImportDraft?
    @State private var selectedDayID: UUID?
    @State private var selectedImportDayIDs: Set<UUID> = []
    @FocusState private var nameFocused: Bool
    private let initialName: String
    private let initialExercises: [WorkoutExercise]
    private let isEditing: Bool
    private let defaultSets: Int
    private let defaultRepetitions: Int
    private let defaultRestSeconds: Int
    private let onSave: (String, [WorkoutExercise]) -> Void
    private let onSaveImportedRoutines: (([Routine]) -> Void)?
    private let onBackToUpload: (() -> Void)?
    private let initialImportDraft: WorkoutImportDraft?
    private let initialSelectedImportDayIDs: Set<UUID>

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
        onSaveImportedRoutines = nil
        onBackToUpload = nil
        initialImportDraft = nil
        initialSelectedImportDayIDs = []
    }

    @MainActor init(importedDraft: WorkoutImportDraft,
                    onSaveImportedRoutines: @escaping ([Routine]) -> Void,
                    onBackToUpload: @escaping () -> Void) {
        var draft = importedDraft
        if draft.days.count == 1, draft.days[0].name == "Day 1" {
            draft.days[0].name = draft.name
        }
        _name = State(initialValue: "")
        _exercises = State(initialValue: [])
        _importDraft = State(initialValue: draft)
        let firstRoutine = draft.days.first { !$0.exercises.isEmpty } ?? draft.days.first
        _selectedDayID = State(initialValue: firstRoutine?.id)
        let selectedIDs = Set(firstRoutine.map { [$0.id] } ?? [])
        _selectedImportDayIDs = State(initialValue: selectedIDs)
        initialName = ""
        initialExercises = []
        isEditing = false
        defaultSets = 3
        defaultRepetitions = 10
        defaultRestSeconds = 60
        onSave = { _, _ in }
        self.onSaveImportedRoutines = onSaveImportedRoutines
        self.onBackToUpload = onBackToUpload
        initialImportDraft = draft
        initialSelectedImportDayIDs = selectedIDs
    }

    private var isDirty: Bool {
        if let initialImportDraft {
            return importDraft != initialImportDraft || selectedImportDayIDs != initialSelectedImportDayIDs
        }
        return name != initialName || exercises != initialExercises
    }
    private var canSave: Bool {
        if let importDraft { return importDraft.canSaveRoutines(for: selectedImportDayIDs) }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !exercises.isEmpty && exercises.allSatisfy(\.isValid)
    }

    var body: some View {
        List {
            if let draft = Binding($importDraft) {
                importedFields(draft)
            } else {
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
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(appColors.background)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            if importDraft == nil {
                WorkoutSummaryView(exercises: exercises)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
            }
        }
        .navigationTitle(isEditing ? "Edit Workout" : "Create Workout")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: attemptBackNavigation) {
                    Label("Back", systemImage: "chevron.left")
                        .foregroundStyle(appColors.primary)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(importDraft == nil ? "Save" : "Save \(selectedImportDayIDs.count) \(selectedImportDayIDs.count == 1 ? "Routine" : "Routines")", action: save)
                    .disabled(!canSave)
            }
        }
        .confirmationDialog(importDraft == nil ? "Discard this workout?" : "Discard changes to these routines?",
                            isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard Changes", role: .destructive, action: leaveEditor)
            Button("Keep Editing", role: .cancel) { }
        }
        .sheet(item: $editor) { route in
            ExerciseEditorView(route: route, onCommit: commit)
        }
        .tint(appColors.primary)
        .interactiveDismissDisabled(isDirty)
    }

    @ViewBuilder
    private func importedFields(_ draft: Binding<WorkoutImportDraft>) -> some View {
        if draft.wrappedValue.days.count > 1 {
            Section {
                Picker("Edit routine", selection: $selectedDayID) {
                    ForEach(draft.wrappedValue.days) { day in
                        Text(day.name).tag(Optional(day.id))
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Imported routines")
            } footer: {
                Text("Each selected day is saved as a separate routine.")
            }

            Section("Routines to Save") {
                ForEach(draft.wrappedValue.days) { day in
                    Toggle(day.name, isOn: selectionBinding(for: day.id))
                }
            }
        }

        if let dayIndex = selectedDayIndex(in: draft.wrappedValue) {
            let day = draft.days[dayIndex]
            Section {
                TextField("Routine name", text: day.name)
                    .accessibilityLabel("Routine name")
            } header: {
                Text("Routine Name")
            } footer: {
                Text("Check the exercises and fill in missing details before saving.")
            }
            Section("Exercises") {
                if day.wrappedValue.exercises.isEmpty {
                    ContentUnavailableView("No exercises yet", systemImage: "dumbbell",
                                           description: Text("Add the exercises from the original."))
                }
                ForEach(day.exercises) { exercise in
                    ImportedExerciseFields(exercise: exercise)
                }
                .onDelete { day.wrappedValue.exercises.remove(atOffsets: $0) }
                Button("Add Exercise", systemImage: "plus.circle.fill") {
                    day.wrappedValue.exercises.append(.init())
                }
                .frame(minHeight: 44)
            }

            let unresolved = draft.wrappedValue.unresolvedLines.filter { $0.dayID == day.wrappedValue.id }
            if !unresolved.isEmpty {
                Section {
                    ForEach(unresolved) { line in
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Needs Review · Page \(line.page)", systemImage: "exclamationmark.circle")
                                .foregroundStyle(.orange)
                            Text(line.text).textSelection(.enabled)
                            HStack {
                                Button("Add as Exercise") { draft.wrappedValue.addUnresolvedLine(line) }
                                Spacer()
                                Button("Ignore Row", role: .destructive) { draft.wrappedValue.ignoreUnresolvedLine(line) }
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Rows to review")
                } footer: {
                    Text("Add or ignore each row before saving this routine.")
                }
            }
        }
    }

    private func selectedDayIndex(in draft: WorkoutImportDraft) -> Int? {
        draft.days.firstIndex { $0.id == selectedDayID } ?? draft.days.indices.first
    }

    private func selectionBinding(for dayID: UUID) -> Binding<Bool> {
        Binding(get: { selectedImportDayIDs.contains(dayID) }, set: { isSelected in
            if isSelected {
                selectedImportDayIDs.insert(dayID)
                selectedDayID = dayID
            }
            else { selectedImportDayIDs.remove(dayID) }
        })
    }

    private struct ImportedExerciseFields: View {
        @Binding var exercise: WorkoutImportDraft.Exercise

        private var missingDetails: String {
            var details: [String] = []
            if exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { details.append("name") }
            if exercise.sets == nil { details.append("sets") }
            if exercise.amount == nil { details.append(exercise.isTimed ? "duration" : "reps") }
            if exercise.rest == nil { details.append("rest") }
            return details.joined(separator: ", ")
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                if !exercise.isValid {
                    Label("Needs Review", systemImage: "exclamationmark.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    if !missingDetails.isEmpty {
                        Text("Enter: \(missingDetails)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Check the values: sets 1–99, reps or seconds 1–3600, rest 0–3600 seconds.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if !exercise.reviewNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(exercise.reviewNotes, id: \.self) { note in
                            Label(note, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
                    .background(.yellow.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                }
                TextField("Exercise name", text: $exercise.name)
                    .font(.headline)
                LabeledContent("Sets") {
                    TextField("Enter sets", value: $exercise.sets, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                Toggle("Timed exercise", isOn: $exercise.isTimed)
                LabeledContent(exercise.isTimed ? "Duration (seconds)" : "Reps") {
                    TextField(exercise.isTimed ? "Enter duration" : "Enter reps", value: $exercise.amount, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Rest (seconds)") {
                    TextField("Enter rest time", value: $exercise.rest, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.vertical, 4)
        }
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
    private func attemptBackNavigation() { if isDirty { confirmDiscard = true } else { leaveEditor() } }
    private func leaveEditor() {
        onBackToUpload?()
        dismiss()
    }
    private func save() {
        guard canSave else { return }
        if let importDraft, let onSaveImportedRoutines {
            var previousSymbol: String?
            let routines = importDraft.days.filter { selectedImportDayIDs.contains($0.id) }.map { day in
                let routine = day.makeRoutine(excluding: previousSymbol)
                previousSymbol = routine.symbol
                return routine
            }
            onSaveImportedRoutines(routines)
        } else {
            onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), exercises)
        }
        dismiss()
    }
}

