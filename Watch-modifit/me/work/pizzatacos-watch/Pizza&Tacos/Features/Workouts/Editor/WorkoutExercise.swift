import SwiftUI

struct WorkoutExercise: Identifiable, Equatable {
    var id = UUID()
    var sourceID: String?
    var name = ""
    var sets = 3
    var reps = 10
    var duration: Int?
    var rest = 60
    var sourceSymbol = "dumbbell.fill"
    var sourceMuscleGroups: [String] = []
    init(id: UUID = UUID(), sourceID: String? = nil, name: String = "", sets: Int = 3, reps: Int = 10, duration: Int? = nil, rest: Int = 60, sourceSymbol: String = "dumbbell.fill", sourceMuscleGroups: [String] = []) {
        self.id = id
        self.sourceID = sourceID
        self.name = name
        self.sets = sets
        self.reps = reps
        self.duration = duration
        self.rest = rest
        self.sourceSymbol = sourceSymbol
        self.sourceMuscleGroups = sourceMuscleGroups
    }
    var isTimed: Bool { duration != nil }
    var seconds: Int { sets * (duration ?? reps * 4) + (sets - 1) * rest }
    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...30).contains(sets) && (isTimed ? (1...3600).contains(duration ?? 0) : (1...200).contains(reps)) && (0...600).contains(rest) }
    static let examples = [Self(name: "Bench Press", sets: 4), Self(name: "Lat Pulldown", sets: 4, reps: 12), Self(name: "Shoulder Press", rest: 45)]
    static func duration(_ exercises: [Self]) -> Int {
        exercises.reduce(0) { $0 + $1.seconds } + max(0, exercises.count - 1) * 30
    }
    static func formatted(_ seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated))
    }

    init(_ exercise: FocusExercise) {
        sourceID = exercise.id
        name = exercise.name
        sets = exercise.sets
        reps = exercise.repetitions ?? 10
        duration = exercise.durationSeconds
        rest = exercise.restSeconds
        sourceSymbol = exercise.symbol
        sourceMuscleGroups = exercise.muscleGroups
    }

    func makeFocusExercise() -> FocusExercise {
        FocusExercise(id: sourceID ?? id.uuidString, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                      sets: sets, repetitions: duration == nil ? reps : nil, durationSeconds: duration,
                      restSeconds: rest, symbol: sourceSymbol, muscleGroups: sourceMuscleGroups)
    }
}
