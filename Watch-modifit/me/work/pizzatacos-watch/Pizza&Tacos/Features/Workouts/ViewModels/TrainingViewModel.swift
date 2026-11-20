import Observation

@Observable
final class TrainingViewModel {
    let exercises: [FocusExercise]
    private(set) var selectedIDs: Set<FocusExercise.ID>

    init(exercises: [FocusExercise]) {
        self.exercises = exercises
        selectedIDs = Set(exercises.map(\.id))
    }

    var selectedExercises: [FocusExercise] {
        exercises.filter { selectedIDs.contains($0.id) }
    }

    var totalMinutes: Int { WorkoutTiming.totalMinutes(for: selectedExercises) }
    var allSelected: Bool { selectedIDs.count == exercises.count }
    var hasSelection: Bool { !selectedIDs.isEmpty }

    // Round selected rows together so their displayed times add up to the total.
    var displayedMinutes: [FocusExercise.ID: Int] {
        let selectedIndices = exercises.indices.filter { selectedIDs.contains(exercises[$0].id) }
        let lastSelectedIndex = selectedIndices.last ?? 0
        let exactMinutes = exercises.enumerated().map { index, exercise in
            let seconds = WorkoutTiming.seconds(for: exercise, followedByExercise: index < lastSelectedIndex)
            return Double(seconds) / 60
        }

        var minutes = exactMinutes.map { Int($0.rounded()) }
        for index in selectedIndices {
            minutes[index] = Int(exactMinutes[index].rounded(.down))
        }

        let roundedDownTotal = selectedIndices.reduce(0) { $0 + minutes[$1] }
        let remainder = totalMinutes - roundedDownTotal
        let descendingFractions = selectedIndices.sorted { lhs, rhs in
            exactMinutes[lhs] - Double(minutes[lhs]) > exactMinutes[rhs] - Double(minutes[rhs])
        }
        for index in descendingFractions.prefix(remainder) {
            minutes[index] += 1
        }

        return Dictionary(uniqueKeysWithValues: zip(exercises.map(\.id), minutes))
    }

    func toggle(_ exercise: FocusExercise) {
        if selectedIDs.contains(exercise.id) {
            selectedIDs.remove(exercise.id)
        } else {
            selectedIDs.insert(exercise.id)
        }
    }

    func toggleAll() {
        selectedIDs = allSelected ? [] : Set(exercises.map(\.id))
    }
}
