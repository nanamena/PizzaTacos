import SwiftUI

struct ExerciseEditorRoute: Identifiable {
    let id = UUID()
    var exercise: WorkoutExercise
    var isNew: Bool
}
