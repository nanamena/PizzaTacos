import SwiftUI

struct WatchRoutineView: View {
    let model: WatchWorkoutModel
    let routine: Routine
    @State private var selectedIDs: Set<FocusExercise.ID>
    @State private var selectedCategory: WorkoutActivityCategory?
    @Environment(\.dismiss) private var dismiss

    init(model: WatchWorkoutModel, routine: Routine) {
        self.model = model
        self.routine = routine
        _selectedIDs = State(initialValue: Set(routine.exercises.map(\.id)))
        _selectedCategory = State(initialValue: routine.activityCategory)
    }

    private var selectedExercises: [FocusExercise] {
        routine.exercises.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        let exercises = selectedExercises
        let minutes = WorkoutTiming.totalMinutes(for: exercises)
        List {
            VStack(alignment: .leading) {
                Label("~\(minutes) min", systemImage: "clock")
                    .font(.system(.headline, design: .rounded))
                    .accessibilityLabel("Estimated time, \(minutes) min")

                if routine.exercises.isEmpty {
                    Text("This routine has no exercises.")
                } else if exercises.isEmpty {
                    Text("Select at least one exercise.")
                } else {
                    Text("\(exercises.count) of \(routine.exercises.count) exercises")
                }
            }
            .foregroundStyle(.primary)
            .accessibilityElement(children: .combine)

            Button(model.savesToHealth && selectedCategory == nil ? "Start Without Apple Health" : "Start") {
                start(exercises)
            }
            .buttonStyle(WatchActionStyle(kind: .start))
            .listRowBackground(Color.clear)
            .disabled(model.busy || exercises.isEmpty)

            NavigationLink("Choose Exercises") {
                WatchExerciseSelectionView(exercises: routine.exercises, selectedIDs: $selectedIDs)
            }
            .disabled(routine.exercises.isEmpty)

            if model.savesToHealth {
                Picker("Workout Type", selection: $selectedCategory) {
                    Text("Choose a Type").tag(nil as WorkoutActivityCategory?)
                    ForEach(WorkoutActivityCategory.allCases) { category in
                        Text(category.title).tag(category as WorkoutActivityCategory?)
                    }
                }
            }

            Image(decorative: "ModiFiTMascot")
                .resizable()
                .scaledToFit()
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
        }
        .listStyle(.elliptical)
        .navigationTitle(routine.name)
    }

    private func start(_ exercises: [FocusExercise]) {
        let category = model.savesToHealth ? selectedCategory : nil
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
