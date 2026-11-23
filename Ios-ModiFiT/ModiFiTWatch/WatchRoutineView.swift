import SwiftUI

struct WatchRoutineView: View {
    let model: WatchWorkoutModel
    let routine: Routine
    @State private var selectedCategory: WorkoutActivityCategory?
    @State private var showingWorkoutOptions = false
    @State private var showingHealthChoice = false
    @State private var pendingStartExercises: [FocusExercise] = []
    @Environment(\.dismiss) private var dismiss

    init(model: WatchWorkoutModel, routine: Routine) {
        self.model = model
        self.routine = routine
        _selectedCategory = State(initialValue: routine.activityCategory)
    }

    private var selectionState: WatchExerciseSelectionState? {
        guard model.exerciseSelectionState?.request.routineID == routine.id else { return nil }
        return model.exerciseSelectionState
    }

    private var selectedExercises: [FocusExercise]? {
        guard let ids = selectionState?.selectedExerciseIDs else { return nil }
        let selectedIDs = Set(ids)
        return routine.exercises.filter { selectedIDs.contains($0.id) }
    }

    private var displayedExercises: [FocusExercise] {
        selectedExercises ?? routine.exercises
    }

    var body: some View {
        let minutes = WorkoutTiming.totalMinutes(for: displayedExercises)
        List {
            VStack(alignment: .leading, spacing: 4) {
                Label("~\(minutes) min", systemImage: "clock")
                    .font(.system(.headline, design: .rounded))
                    .accessibilityLabel("Estimated time, \(minutes) min")

                if routine.exercises.isEmpty {
                    Text("This routine has no exercises.")
                } else if let selectedExercises {
                    Text("\(selectedExercises.count) of \(routine.exercises.count) exercises selected")
                } else {
                    Text("\(routine.exercises.count) exercises")
                }
            }
            .foregroundStyle(.primary)
            .accessibilityElement(children: .combine)

            if let selectionState {
                if selectionState.selectedExerciseIDs == nil {
                    Section("Select on iPhone") {
                        Text("Open ModiFiT on your iPhone to choose exercises.")
                        Button("Cancel Selection", role: .cancel) {
                            model.cancelExerciseSelection()
                        }
                    }
                } else if let selectedExercises, !selectedExercises.isEmpty {
                    Section("Selected Exercises") {
                        Button("Start Selected Exercises") {
                            prepareStart(selectedExercises)
                        }
                        .buttonStyle(WatchActionStyle(kind: .start))
                        .disabled(model.busy)

                        ForEach(selectedExercises) { exercise in
                            ExerciseSummaryRow(exercise: exercise)
                        }

                        Button("Choose Exercises Again") {
                            model.clearExerciseSelection()
                        }
                    }
                }
            } else {
                Section("Workout") {
                    Button("Start or Select Exercises") {
                        showingWorkoutOptions = true
                    }
                    .buttonStyle(WatchActionStyle(kind: .start))
                    .disabled(routine.exercises.isEmpty || model.busy)
                }

                Section("Exercises") {
                    ForEach(routine.exercises) { exercise in
                        ExerciseSummaryRow(exercise: exercise)
                    }
                }
            }

            if model.savesToHealth {
                Section("Apple Health") {
                    Picker("Workout Type", selection: $selectedCategory) {
                        Text("Choose a Type").tag(nil as WorkoutActivityCategory?)
                        ForEach(WorkoutActivityCategory.allCases) { category in
                            Text(category.title).tag(category as WorkoutActivityCategory?)
                        }
                    }
                }
            }
        }
        .listStyle(.elliptical)
        .navigationTitle(routine.name)
        .task {
            if selectionState == nil, !routine.exercises.isEmpty {
                showingWorkoutOptions = true
            }
        }
        .confirmationDialog("How do you want to train?", isPresented: $showingWorkoutOptions) {
            if model.savesToHealth && selectedCategory == nil {
                Button("Start Entire Workout Without Apple Health") {
                    start(routine.exercises, recordInHealth: false)
                }
                .disabled(model.busy)
                Button("Choose Workout Type", role: .cancel) { }
            } else {
                Button("Start Entire Workout") {
                    start(routine.exercises)
                }
                .disabled(model.busy)
            }
            Button("Select Exercises on iPhone") {
                model.requestExerciseSelection(for: routine)
            }
            .disabled(model.busy)
        } message: {
            Text("Start the full routine or choose only some exercises on your iPhone.")
        }
        .confirmationDialog("Choose an Apple Health workout type", isPresented: $showingHealthChoice) {
            Button("Start Without Apple Health") {
                start(pendingStartExercises, recordInHealth: false)
            }
            Button("Choose Workout Type", role: .cancel) { }
        } message: {
            Text("Select a type above to save this session in Apple Health, or continue locally.")
        }
    }

    private func prepareStart(_ exercises: [FocusExercise]) {
        guard !exercises.isEmpty else { return }
        if model.savesToHealth && selectedCategory == nil {
            pendingStartExercises = exercises
            showingHealthChoice = true
        } else {
            start(exercises)
        }
    }

    private func start(_ exercises: [FocusExercise], recordInHealth: Bool = true) {
        guard !exercises.isEmpty else { return }
        let category = recordInHealth && model.savesToHealth ? selectedCategory : nil
        let preparedRoutine = Routine(
            id: routine.id,
            name: routine.name,
            symbol: routine.symbol,
            exercises: exercises,
            createdAt: routine.createdAt,
            activityCategory: category
        )
        Task {
            await model.start(preparedRoutine, category: category) {
                dismiss()
            }
        }
    }
}

private struct ExerciseSummaryRow: View {
    let exercise: FocusExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(exercise.name)
                .font(.body)
            Text("\(exercise.instructionSummary) · \(exercise.restSeconds)s rest")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
