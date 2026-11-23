import Foundation

struct WorkoutMascotPose {
    private static let exercises = ["Curl", "Cycle", "LegPress", "Pulley", "Treadmill"]

    static func imageName(for workout: LiveWorkoutSnapshot?, at date: Date, reduceMotion: Bool) -> String {
        guard let workout else { return "WorkoutAnimationCycle1" }
        let now = workout.pausedAt ?? date
        if workout.resting, let deadline = workout.deadline {
            if now >= deadline {
                let melted = !reduceMotion && now.timeIntervalSince(deadline) >= 10
                return melted ? "WorkoutAnimationMelt2" : "WorkoutAnimationMelt1"
            }
            let index = workout.position.set > 1 ? workout.position.exerciseIndex : workout.position.exerciseIndex - 1
            let rest = workout.routine.exercises.indices.contains(index)
                ? workout.routine.exercises[index].restSeconds : 0
            let start = deadline.addingTimeInterval(-Double(rest))
            return "WorkoutAnimationRest\(frame(elapsed: now.timeIntervalSince(start), reduceMotion: reduceMotion))"
        }

        let index = (Int(workout.id.uuid.0) + workout.position.exerciseIndex) % exercises.count
        let pose = frame(elapsed: now.timeIntervalSince(workout.setStartedAt), reduceMotion: reduceMotion)
        return "WorkoutAnimation\(exercises[index])\(pose)"
    }

    private static func frame(elapsed: TimeInterval, reduceMotion: Bool) -> Int {
        guard !reduceMotion else { return 1 }
        return Int((max(0, elapsed) * 5 / 4 + 0.000001).rounded(.down)) % 2 + 1
    }
}
