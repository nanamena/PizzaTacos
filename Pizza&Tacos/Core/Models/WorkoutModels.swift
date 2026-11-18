import Foundation

// Este modelo representa un ejercicio dentro de una sesión activa.
struct FocusExercise: Identifiable, Hashable {
    let id: String
    let name: String
    let sets: Int
    let repetitions: Int?
    let durationSeconds: Int?
    let restSeconds: Int
    let symbol: String
    var muscleGroups: [String] = []

    var instructionSummary: String {
        if let repetitions { return "\(sets) sets × \(repetitions) reps" }
        let duration = durationSeconds.map { "\($0) sec" } ?? "Timed"
        return "\(sets) sets × \(duration)"
    }
}

// Este estado define la fase actual del entrenamiento.
enum WorkoutSessionState: Equatable {
    case ready
    case exercising
    case resting
    case paused
    case completed
}

// Esta ruta identifica las hojas de ejercicios y sus detalles.
enum FocusWorkoutSheet: Identifiable {
    case exerciseList
    case exerciseDetail(FocusExercise)

    var id: String {
        switch self {
        case .exerciseList: "exercise-list"
        case .exerciseDetail(let exercise): "exercise-\(exercise.id)"
        }
    }
}

import Foundation

// Estas categorías representan la respuesta de ánimo después de una rutina completada.
enum WorkoutFeeling: String, CaseIterable, Identifiable, Codable {
    case veryBad = "Very Bad"
    case bad = "Bad"
    case normal = "Normal"
    case prettyGood = "Pretty Good"
    case excellent = "Excellent"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .veryBad: "exclamationmark.circle.fill"
        case .bad: "hand.thumbsdown.fill"
        case .normal: "minus.circle.fill"
        case .prettyGood: "hand.thumbsup.fill"
        case .excellent: "star.fill"
        }
    }
}

// Este registro asocia el estado de ánimo a una sesión concreta y su fecha de finalización.
struct WorkoutHistoryRecord: Codable, Identifiable {
    let id: UUID
    let routineID: String
    let routineName: String
    let completedAt: Date
    let durationSeconds: Int
    let completedExercises: Int
    let muscleGroups: [String]
    var feeling: WorkoutFeeling?

    init(id: UUID = UUID(), routineID: String, routineName: String, completedAt: Date,
         durationSeconds: Int, completedExercises: Int, muscleGroups: [String], feeling: WorkoutFeeling? = nil) {
        self.id = id
        self.routineID = routineID
        self.routineName = routineName
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.completedExercises = completedExercises
        self.muscleGroups = muscleGroups
        self.feeling = feeling
    }
}
import Foundation

// Este modelo representa una rutina que aparece en la colección de entrenamientos.
struct Routine: Identifiable, Hashable {
    let id: String
    let name: String
    let exerciseCount: Int
    let estimatedMinutes: Int
    let symbol: String
}

// Este modelo agrupa la información resumida de la sesión programada para hoy.
struct TodayWorkout {
    let name: String
    let exerciseCount: Int
    let estimatedMinutes: Int
}

// Esta enumeración define las tres áreas principales de la aplicación.
enum AppTab: String, CaseIterable, Identifiable {
    case workouts = "Workouts"
    case progress = "Progress"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .workouts: "dumbbell.fill"
        case .progress: "chart.bar.fill"
        case .settings: "gearshape.fill"
        }
    }
}
