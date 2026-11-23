import Foundation

struct WatchWorkoutState: Codable {
    let id: UUID
    let routine: Routine
    let startedAt: Date
    var position = WorkoutPosition()
    var setStartedAt: Date?
    var deadline: Date?
    var resting = false
    var pausedAt: Date?
    var pausedSeconds: TimeInterval = 0
    var health: WatchHealthStatus

    var exercise: FocusExercise { routine.exercises[position.exerciseIndex] }

    var liveWorkout: LiveWorkoutSnapshot {
        LiveWorkoutSnapshot(id: id, routine: routine, position: position, resting: resting,
                            setStartedAt: setStartedAt ?? startedAt, deadline: deadline, pausedAt: pausedAt)
    }

    init(id: UUID = UUID(), routine: Routine, startedAt: Date, health: WatchHealthStatus) {
        self.id = id
        self.routine = routine
        self.startedAt = startedAt
        self.health = health
        startSet(at: startedAt)
    }

    mutating func finishSet(at date: Date, nextSetStartsAt: Date) -> Bool {
        let rest = exercise.restSeconds
        guard !position.finishSet(in: routine.exercises) else { return true }
        resting = rest > 0
        if resting {
            deadline = date.addingTimeInterval(Double(rest))
        } else {
            startSet(at: nextSetStartsAt)
        }
        return false
    }

    mutating func startSet(at date: Date) {
        resting = false
        setStartedAt = date
        deadline = exercise.durationSeconds.map { date.addingTimeInterval(Double($0)) }
    }

    mutating func togglePause(at date: Date) {
        if let pausedAt {
            let interval = max(0, date.timeIntervalSince(pausedAt))
            pausedSeconds += interval
            deadline = deadline?.addingTimeInterval(interval)
            setStartedAt = (setStartedAt ?? startedAt).addingTimeInterval(interval)
            self.pausedAt = nil
        } else {
            pausedAt = date
        }
    }

    func completed(at date: Date) -> WatchWorkoutResult {
        WatchWorkoutResult(record: WorkoutHistoryRecord(id: id, routineID: routine.id, routineName: routine.name,
            completedAt: date, durationSeconds: max(0, Int(date.timeIntervalSince(startedAt) - pausedSeconds)),
            completedExercises: position.completedExercises, muscleGroups: []),
            health: health == .recording ? .saving : health)
    }
}

enum WatchHealthStatus: String, Codable {
    case off, recording, saving, saved, failed
}

struct WatchWorkoutResult: Codable {
    var record: WorkoutHistoryRecord
    var health: WatchHealthStatus
    var synced = false
}

struct WatchWorkoutStorage: Codable {
    var active: WatchWorkoutState?
    var results: [WatchWorkoutResult] = []
    var exerciseSelection: WatchExerciseSelectionState?
}
