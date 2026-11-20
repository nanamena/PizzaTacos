extension Routine {
    static let samples = [
        Routine(
            id: "upper",
            name: "Upper Body",
            symbol: "dumbbell",
            exercises: [
                FocusExercise(id: "bench", name: "Bench Press", sets: 4, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "dumbbell.fill"),
                FocusExercise(id: "shoulder", name: "Shoulder Press", sets: 3, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "dumbbell.fill"),
                FocusExercise(id: "lat", name: "Lat Pulldown", sets: 3, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "figure.strengthtraining.traditional"),
                FocusExercise(id: "curl", name: "Bicep Curl", sets: 3, repetitions: 12, durationSeconds: nil, restSeconds: 45, symbol: "dumbbell.fill"),
                FocusExercise(id: "tricep", name: "Tricep Extension", sets: 3, repetitions: 12, durationSeconds: nil, restSeconds: 45, symbol: "dumbbell.fill")
            ]
        ),
        Routine(
            id: "lower",
            name: "Lower Body",
            symbol: "figure.walk",
            exercises: [
                FocusExercise(id: "squat", name: "Goblet Squat", sets: 4, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "figure.strengthtraining.traditional"),
                FocusExercise(id: "deadlift", name: "Romanian Deadlift", sets: 3, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "dumbbell.fill"),
                FocusExercise(id: "lunge", name: "Reverse Lunge", sets: 3, repetitions: 10, durationSeconds: nil, restSeconds: 45, symbol: "figure.walk"),
                FocusExercise(id: "bridge", name: "Glute Bridge", sets: 3, repetitions: 12, durationSeconds: nil, restSeconds: 45, symbol: "figure.core.training"),
                FocusExercise(id: "calf", name: "Calf Raise", sets: 3, repetitions: 15, durationSeconds: nil, restSeconds: 45, symbol: "figure.stand")
            ]
        ),
        Routine(
            id: "full",
            name: "Full Body",
            symbol: "figure.strengthtraining.traditional",
            exercises: [
                FocusExercise(id: "press", name: "Bench Press", sets: 4, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "dumbbell.fill"),
                FocusExercise(id: "row", name: "Dumbbell Row", sets: 3, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "dumbbell.fill"),
                FocusExercise(id: "squat", name: "Goblet Squat", sets: 4, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "figure.strengthtraining.traditional"),
                FocusExercise(id: "shoulder", name: "Shoulder Press", sets: 3, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "dumbbell.fill"),
                FocusExercise(id: "bridge", name: "Glute Bridge", sets: 3, repetitions: 12, durationSeconds: nil, restSeconds: 45, symbol: "figure.core.training"),
                FocusExercise(id: "plank", name: "Plank", sets: 3, repetitions: nil, durationSeconds: 30, restSeconds: 45, symbol: "figure.core.training"),
                FocusExercise(id: "curl", name: "Bicep Curl", sets: 3, repetitions: 12, durationSeconds: nil, restSeconds: 45, symbol: "dumbbell.fill"),
                FocusExercise(id: "calf", name: "Calf Raise", sets: 3, repetitions: 15, durationSeconds: nil, restSeconds: 45, symbol: "figure.stand")
            ]
        )
    ]
}
