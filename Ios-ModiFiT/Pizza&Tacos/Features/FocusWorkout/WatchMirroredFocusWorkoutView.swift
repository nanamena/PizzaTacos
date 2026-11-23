import SwiftUI

struct WatchMirroredFocusWorkoutView: View {
    let workout: LiveWorkoutSnapshot
    let link: LiveWorkoutLink
    let onClose: () -> Void

    private var activeSetDeadline: Date? {
        workout.pausedAt == nil && !workout.resting ? workout.deadline : nil
    }

    var body: some View {
        FocusWorkoutSetView(
            routine: workout.routine,
            workout: workout,
            actionsEnabled: link.isConnected && !link.commandPending,
            commandRejected: link.commandRejected,
            onBrowseRoutines: link.isConnected ? nil : onClose,
            timing: timing(at:),
            onAction: { link.sendAction($0, for: workout.id) }
        )
        .sensoryFeedback(.success, trigger: workout.position.completedSets)
        .task(id: activeSetDeadline) {
            guard let deadline = activeSetDeadline else { return }
            do {
                try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
                link.refreshRemoteWorkout()
            } catch {
                // A newer set or a pause superseded this deadline.
            }
        }
    }

    private func timing(at date: Date) -> (remaining: String, delay: String?) {
        let now = workout.pausedAt ?? date
        let deadlineRemaining = workout.deadline.map { max(0, Int(ceil($0.timeIntervalSince(now)))) } ?? 0
        let plannedSetTime = WorkoutTiming.secondsPerSet(for: workout.exercise)
        let elapsed = max(0, now.timeIntervalSince(workout.setStartedAt))
        let currentSetRemaining = workout.deadline == nil
            ? max(0, Int(ceil(Double(plannedSetTime) - elapsed)))
            : deadlineRemaining
        let delay = !workout.resting && workout.deadline == nil ? max(0, Int(elapsed) - plannedSetTime) : 0

        let exercises = workout.routine.exercises
        let currentIndex = workout.position.exerciseIndex
        var remaining = workout.resting ? deadlineRemaining : currentSetRemaining
        for index in currentIndex..<exercises.count {
            let exercise = exercises[index]
            let setCount = index == currentIndex ? exercise.sets - workout.position.set + 1 : exercise.sets
            let includesCurrentSet = index == currentIndex && !workout.resting
            let futureSets = setCount - (includesCurrentSet ? 1 : 0)
            let rests = index < exercises.count - 1 ? setCount : max(0, setCount - 1)
            remaining += futureSets * WorkoutTiming.secondsPerSet(for: exercise) + rests * exercise.restSeconds
        }
        return ("≈ \(Self.timeString(remaining))", delay > 0 ? "+\(Self.timeString(delay)) this set" : nil)
    }

    private static func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
