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

    var id: String {
        switch self {
        case .exerciseList: "exercise-list"
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
    let symbol: String
    let exercises: [FocusExercise]

    var exerciseCount: Int { exercises.count }
    var estimatedMinutes: Int { WorkoutTiming.totalMinutes(for: exercises) }
}

enum WorkoutTiming {
    private static let secondsPerRep = 4
    private static let transitionSeconds = 35

    static func seconds(for exercise: FocusExercise, followedByExercise: Bool) -> Int {
        let secondsPerSet = exercise.durationSeconds ?? (exercise.repetitions ?? 0) * secondsPerRep
        let restCount = followedByExercise ? exercise.sets : max(exercise.sets - 1, 0)
        let transition = followedByExercise ? transitionSeconds : 0
        return exercise.sets * secondsPerSet + restCount * exercise.restSeconds + transition
    }

    static func totalMinutes(for exercises: [FocusExercise]) -> Int {
        let totalSeconds = exercises.enumerated().reduce(0) { sum, entry in
            sum + seconds(for: entry.element, followedByExercise: entry.offset < exercises.count - 1)
        }
        return Int((Double(totalSeconds) / 60).rounded())
    }
}

// Este modelo agrupa la información resumida de la sesión programada para hoy.
struct TodayWorkout {
    let name: String
    let exerciseCount: Int
    let estimatedMinutes: Int
}

// Esta enumeración define las tres áreas principales de la aplicación.
enum AppTab: Hashable {
    case workouts
    case progress
    case settings
}
