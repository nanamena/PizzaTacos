// Workout position advances the same way on the phone and the watch.
struct WorkoutPosition: Codable, Equatable {
    var exerciseIndex = 0
    var set = 1
    var completedExercises = 0
    var completedSets = 0

    mutating func finishSet(in exercises: [FocusExercise]) -> Bool {
        let exercise = exercises[exerciseIndex]
        completedSets += 1
        if set < exercise.sets {
            set += 1
            return false
        }
        completedExercises += 1
        guard exerciseIndex + 1 < exercises.count else { return true }
        exerciseIndex += 1
        set = 1
        return false
    }
}
