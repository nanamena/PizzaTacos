import SwiftUI

struct WatchExerciseSelectionView: View {
    let exercises: [FocusExercise]
    @Binding var selectedIDs: Set<FocusExercise.ID>

    var body: some View {
        let selectedExercises = exercises.filter { selectedIDs.contains($0.id) }
        let allSelected = selectedExercises.count == exercises.count
        let minutes = WorkoutTiming.totalMinutes(for: selectedExercises)

        List {
            Label("~\(minutes) min", systemImage: "clock")
                .font(.headline)
                .accessibilityLabel("Estimated time, \(minutes) min")

            Button(allSelected ? "Deselect All" : "Select All") {
                selectedIDs = allSelected ? [] : Set(exercises.map(\.id))
            }

            ForEach(exercises) { exercise in
                Toggle(exercise.name, isOn: inclusion(of: exercise.id))
            }
        }
        .listStyle(.elliptical)
        .navigationTitle("Exercises")
    }

    private func inclusion(of id: FocusExercise.ID) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(id) },
            set: { isIncluded in
                if isIncluded {
                    selectedIDs.insert(id)
                } else {
                    selectedIDs.remove(id)
                }
            }
        )
    }
}
