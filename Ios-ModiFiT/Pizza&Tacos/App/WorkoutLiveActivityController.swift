import ActivityKit
import Foundation

@MainActor
final class WorkoutLiveActivityController {
    private struct Record {
        let attributes: WorkoutActivityAttributes
        let state: WorkoutActivityAttributes.ContentState
        let isWatchWorkout: Bool
    }

    private var records: [UUID: Record] = [:]
    private var appIsActive = false
    private var updateTask: Task<Void, Never>?
    private var palette: AppPalette = .terracotta

    func updatePalette(_ palette: AppPalette) {
        guard self.palette != palette else { return }
        self.palette = palette
        for workoutID in Array(records.keys) {
            guard let record = records[workoutID] else { continue }
            let state = Self.contentState(
                for: record.state,
                palette: palette
            )
            records[workoutID] = Record(attributes: record.attributes, state: state, isWatchWorkout: record.isWatchWorkout)
            enqueueUpdate(for: workoutID)
        }
    }

    func setAppIsActive(_ isActive: Bool) {
        appIsActive = isActive
        guard isActive else { return }
        for workoutID in Array(records.keys) {
            enqueueUpdate(for: workoutID)
        }
    }

    func flushUpdates() async {
        await updateTask?.value
    }

    func refreshExistingActivity(for workoutID: UUID) {
        guard records[workoutID] != nil else { return }
        enqueueUpdate(for: workoutID, allowStart: false)
    }

    func receive(_ workout: LiveWorkoutSnapshot?, sourceID: UUID, revision: Int,
                 isWatchWorkout: Bool, canAdvance: Bool) {
        guard let workout else {
            end(sourceID: sourceID)
            return
        }

        let attributes = WorkoutActivityAttributes(
            workoutID: workout.id,
            sourceID: sourceID,
            routineName: workout.routine.name,
            isWatchWorkout: isWatchWorkout
        )
        let state = Self.contentState(for: workout, revision: revision, canAdvance: canAdvance, palette: palette)
        guard records[workout.id]?.attributes != attributes || records[workout.id]?.state != state else { return }
        records[workout.id] = Record(attributes: attributes, state: state, isWatchWorkout: isWatchWorkout)
        enqueueUpdate(for: workout.id)
    }

    func remoteReachabilityChanged(_ isReachable: Bool) {
        for workoutID in Array(records.keys) {
            guard let record = records[workoutID], record.isWatchWorkout else { continue }
            let state = WorkoutActivityAttributes.ContentState(
                revision: record.state.revision,
                exerciseName: record.state.exerciseName,
                exerciseIndex: record.state.exerciseIndex,
                exerciseCount: record.state.exerciseCount,
                setNumber: record.state.setNumber,
                setsInExercise: record.state.setsInExercise,
                isResting: record.state.isResting,
                pausedAt: record.state.pausedAt,
                timerStartAt: record.state.timerStartAt,
                deadline: record.state.deadline,
                canAdvance: isReachable && record.state.pausedAt == nil,
                lightButtonColor: record.state.lightButtonColor,
                darkButtonColor: record.state.darkButtonColor,
                lightKeylineColor: record.state.lightKeylineColor,
                darkKeylineColor: record.state.darkKeylineColor
            )
            records[workoutID] = Record(attributes: record.attributes, state: state, isWatchWorkout: true)
            enqueueUpdate(for: workoutID)
        }
    }

    func end(sourceID: UUID) {
        records = records.filter { $0.value.attributes.sourceID != sourceID }
        let previous = updateTask
        updateTask = Task { @MainActor in
            await previous?.value
            for activity in Activity<WorkoutActivityAttributes>.activities
                where activity.attributes.sourceID == sourceID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func endAllActivities() {
        records.removeAll()
        let previous = updateTask
        updateTask = Task { @MainActor in
            await previous?.value
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func enqueueUpdate(for workoutID: UUID, allowStart: Bool = true) {
        let previous = updateTask
        updateTask = Task { @MainActor [weak self] in
            await previous?.value
            await self?.applyLatestRecord(for: workoutID, allowStart: allowStart)
        }
    }

    private func applyLatestRecord(for workoutID: UUID, allowStart: Bool) async {
        guard let record = records[workoutID] else {
            for activity in Activity<WorkoutActivityAttributes>.activities
                where activity.attributes.workoutID == workoutID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        let existingActivity = Activity<WorkoutActivityAttributes>.activities.first {
            $0.attributes.workoutID == workoutID && $0.attributes.sourceID == record.attributes.sourceID
        }
        if let existingActivity {
            await existingActivity.update(ActivityContent(state: record.state, staleDate: nil))
            return
        }

        guard allowStart else { return }
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        guard appIsActive, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try? Activity.request(
            attributes: record.attributes,
            content: ActivityContent(state: record.state, staleDate: nil),
            pushType: nil
        )
    }

    private static func contentState(for workout: LiveWorkoutSnapshot, revision: Int,
                                     canAdvance: Bool, palette: AppPalette) -> WorkoutActivityAttributes.ContentState {
        var timerStartAt = workout.setStartedAt
        if workout.resting, let deadline = workout.deadline {
            let restIndex = workout.position.set > 1
                ? workout.position.exerciseIndex
                : workout.position.exerciseIndex - 1
            let restDuration = workout.routine.exercises.indices.contains(restIndex)
                ? workout.routine.exercises[restIndex].restSeconds : 0
            timerStartAt = deadline.addingTimeInterval(-Double(restDuration))
        }

        return WorkoutActivityAttributes.ContentState(
            revision: revision,
            exerciseName: workout.exercise.name,
            exerciseIndex: workout.position.exerciseIndex,
            exerciseCount: workout.routine.exercises.count,
            setNumber: workout.position.set,
            setsInExercise: workout.exercise.sets,
            isResting: workout.resting,
            pausedAt: workout.pausedAt,
            timerStartAt: timerStartAt,
            deadline: workout.deadline,
            canAdvance: canAdvance && workout.pausedAt == nil,
            lightButtonColor: palette.colors.primary,
            darkButtonColor: palette.colors.darkSecondary,
            lightKeylineColor: palette.colors.primary,
            darkKeylineColor: palette.colors.darkPrimary
        )
    }

    private static func contentState(for state: WorkoutActivityAttributes.ContentState,
                                     palette: AppPalette) -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            revision: state.revision,
            exerciseName: state.exerciseName,
            exerciseIndex: state.exerciseIndex,
            exerciseCount: state.exerciseCount,
            setNumber: state.setNumber,
            setsInExercise: state.setsInExercise,
            isResting: state.isResting,
            pausedAt: state.pausedAt,
            timerStartAt: state.timerStartAt,
            deadline: state.deadline,
            canAdvance: state.canAdvance,
            lightButtonColor: palette.colors.primary,
            darkButtonColor: palette.colors.darkSecondary,
            lightKeylineColor: palette.colors.primary,
            darkKeylineColor: palette.colors.darkPrimary
        )
    }
}
