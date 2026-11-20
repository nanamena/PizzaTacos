import Foundation
import Combine
import HealthKit

// Este ViewModel coordina la sesión, las transiciones entre sets y el temporizador.
@MainActor
final class FocusWorkoutViewModel: ObservableObject {
    @Published private(set) var state: WorkoutSessionState = .ready
    @Published private(set) var exerciseIndex = 0
    @Published private(set) var currentSet = 1
    @Published private(set) var remainingSeconds = 0
    @Published private(set) var restTimeExpired = false
    @Published private(set) var restOvertimeSeconds = 0
    @Published private(set) var restLeadsToNextExercise = false
    @Published private(set) var countdownDuration = 0
    @Published private(set) var completedExercises = 0
    @Published private(set) var completedSets = 0
    @Published private(set) var sessionDurationSeconds = 0
    @Published var showingEndConfirmation = false
    @Published var showingExitConfirmation = false
    @Published var presentedSheet: FocusWorkoutSheet?
    @Published private(set) var endedEarly = false
    @Published private(set) var healthSaveStatus: HealthWorkoutSaveStatus = .off
    @Published private(set) var activeEnergyKilocalories: Double?

    let routine: Routine
    let exercises: [FocusExercise]
    let workoutID = UUID()
    private let historyStore: WorkoutHistoryStore
    private let healthSession = AppleHealthWorkoutSession()

    private var timerTask: Task<Void, Never>?
    private var countdownDeadline: Date?
    private var restOvertimeStartedAt: Date?
    private var activeRestDuration = 0
    private var pausedFromState: WorkoutSessionState = .exercising
    private var sessionStartedAt: Date?
    private var currentSetStartedAt: Date?
    private var estimatedWorkoutDurationSeconds = 0
    private var sessionEndedAt: Date?
    private var totalPausedSeconds: TimeInterval = 0
    private var pauseStartedAt: Date?

    init(routine: Routine, historyStore: WorkoutHistoryStore) {
        self.routine = routine
        self.historyStore = historyStore
        exercises = routine.exercises
    }

    var currentExercise: FocusExercise { exercises[min(exerciseIndex, exercises.count - 1)] }
    var currentExerciseNumber: Int { min(exerciseIndex + 1, exercises.count) }
    var pausedStateIsTimedExercise: Bool { pausedFromState == .exercising && currentExercise.durationSeconds != nil }
    var isShowingRest: Bool { state == .resting || (state == .paused && pausedFromState == .resting) }
    var progressLabel: String { "\(currentExerciseNumber) of \(exercises.count)" }
    var segmentProgress: Double { Double(completedExercises) / Double(max(exercises.count, 1)) }
    var currentTimeText: String {
        if currentExercise.durationSeconds != nil && (state == .exercising || state == .paused) {
            return Self.timeString(remainingSeconds)
        }
        return currentExercise.repetitions.map { "\($0) reps" } ?? "Exercise"
    }
    var setLabel: String { "Set \(currentSet) of \(currentExercise.sets)" }
    var elapsedTimerStart: Date? { sessionStartedAt?.addingTimeInterval(totalPausedSeconds) }
    private var elapsedWorkoutSeconds: Int {
        guard let sessionStartedAt else { return 0 }
        let end = sessionEndedAt ?? pauseStartedAt ?? Date()
        return max(0, Int(end.timeIntervalSince(sessionStartedAt) - totalPausedSeconds))
    }
    var elapsedWorkoutText: String {
        Self.timeString(elapsedWorkoutSeconds)
    }
    private var projectedScheduleDelaySeconds: Int {
        guard estimatedWorkoutDurationSeconds > 0 else { return 0 }
        return max(0, elapsedWorkoutSeconds + estimatedRemainingSeconds - estimatedWorkoutDurationSeconds)
    }
    private var currentSetOvertimeSeconds: Int {
        switch state {
        case .exercising:
            return setOvertimeSeconds(at: Date())
        case .paused where pausedFromState == .exercising:
            return setOvertimeSeconds(at: pauseStartedAt ?? Date())
        default:
            return 0
        }
    }
    var remainingWorkoutText: String {
        let carriedDelay = max(0, projectedScheduleDelaySeconds - currentSetOvertimeSeconds)
        return "≈ \(Self.timeString(estimatedRemainingSeconds + carriedDelay))"
    }
    var workoutDelayText: String? {
        guard currentSetOvertimeSeconds > 0 else { return nil }
        return "+\(Self.timeString(currentSetOvertimeSeconds)) this set"
    }
    var nextExercise: FocusExercise? {
        if state == .resting { return exercises.indices.contains(exerciseIndex) ? exercises[exerciseIndex] : nil }
        let nextIndex = exerciseIndex + 1
        return exercises.indices.contains(nextIndex) ? exercises[nextIndex] : nil
    }
    var stateTitle: String {
        switch state {
        case .ready, .exercising: "Exercise"
        case .resting: "Rest"
        case .paused: pausedFromState == .resting ? "Rest · Paused" : "Paused"
        case .completed: endedEarly ? "Workout Ended" : "Workout Completed!"
        }
    }

    // Esta función inicia la sesión y activa de inmediato el primer ejercicio.
    func startWorkout() async {
        guard state == .ready else { return }
        if let category = routine.activityCategory,
           AppleHealthAccess.shared.savesWorkouts,
           AppleHealthAccess.shared.canWriteWorkouts {
            healthSaveStatus = .starting
            do {
                sessionStartedAt = try await healthSession.start(category: category, recordID: workoutID)
                healthSaveStatus = .recording
            } catch {
                healthSaveStatus = .failed
                sessionStartedAt = Date()
            }
        } else {
            sessionStartedAt = Date()
        }
        estimatedWorkoutDurationSeconds = WorkoutTiming.totalSeconds(for: exercises)
        state = .exercising
        startTimedExerciseIfNeeded()
    }

    // Esta función pausa el estado actual y conserva el tiempo exacto restante.
    func pauseWorkout() {
        guard state == .exercising || state == .resting else { return }
        pausedFromState = state
        if let deadline = countdownDeadline {
            remainingSeconds = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
            countdownDeadline = nil
        }
        if restTimeExpired, let started = restOvertimeStartedAt {
            restOvertimeSeconds = max(0, Int(Date().timeIntervalSince(started)))
        }
        timerTask?.cancel()
        timerTask = nil
        pauseStartedAt = Date()
        if healthSaveStatus == .recording { healthSession.pause() }
        state = .paused
    }

    // Esta función reanuda el conteo desde la fecha límite restante o el set pausado.
    func resumeWorkout() {
        guard state == .paused else { return }
        if let pauseStartedAt {
            let pauseDuration = Date().timeIntervalSince(pauseStartedAt)
            totalPausedSeconds += pauseDuration
            if restTimeExpired { restOvertimeStartedAt = restOvertimeStartedAt?.addingTimeInterval(pauseDuration) }
            if pausedFromState == .exercising { currentSetStartedAt = currentSetStartedAt?.addingTimeInterval(pauseDuration) }
        }
        pauseStartedAt = nil
        if healthSaveStatus == .recording { healthSession.resume() }
        state = pausedFromState
        if pausedFromState == .resting && restTimeExpired {
            startRestOvertime()
        } else if (pausedFromState == .resting && !restTimeExpired) || (pausedFromState == .exercising && currentExercise.durationSeconds != nil) {
            startCountdown(seconds: remainingSeconds, phase: pausedFromState)
        }
    }

    // Esta función marca el set actual sin asumir que las repeticiones se midieron automáticamente.
    func finishCurrentSet() {
        guard state == .exercising else { return }
        timerTask?.cancel()
        timerTask = nil
        countdownDeadline = nil
        completedSets += 1

        let finishedExercise = currentExercise
        restLeadsToNextExercise = currentSet >= finishedExercise.sets
        if currentSet >= finishedExercise.sets {
            completedExercises += 1
            if exerciseIndex + 1 >= exercises.count {
                completeWorkout(endedEarly: false)
                return
            }
            exerciseIndex += 1
            currentSet = 1
        } else {
            currentSet += 1
        }

        activeRestDuration = max(0, finishedExercise.restSeconds)
        restTimeExpired = false
        restOvertimeStartedAt = nil
        restOvertimeSeconds = 0
        if activeRestDuration > 0 {
            startCountdown(seconds: activeRestDuration, phase: .resting)
        } else {
            state = .exercising
            startTimedExerciseIfNeeded()
        }
    }

    // Esta función salta solo el descanso activo y comienza el set siguiente.
    func skipRest() {
        guard state == .resting else { return }
        timerTask?.cancel()
        timerTask = nil
        countdownDeadline = nil
        remainingSeconds = 0
        restTimeExpired = false
        restOvertimeStartedAt = nil
        restOvertimeSeconds = 0
        state = .exercising
        startTimedExerciseIfNeeded()
    }

    // Esta función reinicia la sesión desde el primer ejercicio y su primer set.
    func restartWorkout() {
        healthSession.discard()
        timerTask?.cancel()
        timerTask = nil
        countdownDeadline = nil
        exerciseIndex = 0
        currentSet = 1
        restTimeExpired = false
        restLeadsToNextExercise = false
        restOvertimeStartedAt = nil
        restOvertimeSeconds = 0
        completedExercises = 0
        completedSets = 0
        totalPausedSeconds = 0
        pauseStartedAt = nil
        sessionStartedAt = nil
        estimatedWorkoutDurationSeconds = WorkoutTiming.totalSeconds(for: exercises)
        sessionEndedAt = nil
        endedEarly = false
        healthSaveStatus = .off
        activeEnergyKilocalories = nil
        state = .ready
        Task { await startWorkout() }
    }

    // Esta función termina anticipadamente y detiene cualquier temporizador pendiente.
    func endWorkout() {
        completeWorkout(endedEarly: true)
    }

    // Esta función abre la lista completa sin cambiar el ejercicio activo.
    func showExerciseList() {
        presentedSheet = .exerciseList
    }

    // Esta función cuenta hacia atrás usando una fecha límite para evitar deriva del temporizador.
    private func startCountdown(seconds: Int, phase: WorkoutSessionState) {
        timerTask?.cancel()
        countdownDuration = max(0, seconds)
        remainingSeconds = max(0, seconds)
        state = phase
        guard seconds > 0 else {
            countdownFinished(phase: phase)
            return
        }

        countdownDeadline = Date().addingTimeInterval(TimeInterval(seconds))
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let deadline = self.countdownDeadline else { return }
                let secondsLeft = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
                if self.remainingSeconds != secondsLeft {
                    self.remainingSeconds = secondsLeft
                }
                if secondsLeft == 0 {
                    self.timerTask = nil
                    self.countdownDeadline = nil
                    self.countdownFinished(phase: phase, expiredAt: deadline)
                    return
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func countdownFinished(phase: WorkoutSessionState, expiredAt: Date = Date()) {
        guard state != .paused && state != .completed else { return }
        if phase == .resting {
            restTimeExpired = true
            restOvertimeStartedAt = expiredAt
            startRestOvertime()
        } else if phase == .exercising {
            finishCurrentSet()
        }
    }

    private func startRestOvertime() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.state == .resting, let started = self.restOvertimeStartedAt else { return }
                let overtimeSeconds = max(0, Int(Date().timeIntervalSince(started)))
                if self.restOvertimeSeconds != overtimeSeconds {
                    self.restOvertimeSeconds = overtimeSeconds
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    // Esta función inicia un conteo para ejercicios con duración configurada.
    private func startTimedExerciseIfNeeded() {
        currentSetStartedAt = Date()
        guard let duration = currentExercise.durationSeconds else { return }
        startCountdown(seconds: duration, phase: .exercising)
    }

    // Esta función completa el entrenamiento y calcula el tiempo efectivo de la sesión.
    private func completeWorkout(endedEarly: Bool) {
        guard state != .completed else { return }
        timerTask?.cancel()
        timerTask = nil
        countdownDeadline = nil
        self.endedEarly = endedEarly
        sessionEndedAt = Date()
        let start = sessionStartedAt ?? sessionEndedAt!
        let paused = totalPausedSeconds + (pauseStartedAt.map { sessionEndedAt!.timeIntervalSince($0) } ?? 0)
        sessionDurationSeconds = max(0, Int(sessionEndedAt!.timeIntervalSince(start) - paused))
        state = .completed
        if !endedEarly {
            historyStore.record(WorkoutHistoryRecord(id: workoutID,
                                                     routineID: routine.id,
                                                     routineName: routine.name,
                                                     completedAt: sessionEndedAt!,
                                                     durationSeconds: sessionDurationSeconds,
                                                     completedExercises: completedExercises,
                                                     muscleGroups: []))
            if healthSaveStatus == .recording {
                healthSaveStatus = .saving
                let endDate = sessionEndedAt!
                Task {
                    do {
                        let workout = try await healthSession.finish(at: endDate)
                        historyStore.linkHealthWorkout(workout.uuid, to: workoutID)
                        activeEnergyKilocalories = AppleHealthWorkoutSession.activeEnergyKilocalories(from: workout)
                        healthSaveStatus = .saved
                    } catch {
                        healthSession.discard()
                        healthSaveStatus = .failed
                    }
                }
            }
        } else {
            healthSession.discard()
            healthSaveStatus = .off
        }
    }

    // Esta propiedad estima el tiempo restante y distingue la duración conocida de las repeticiones.
    private var estimatedRemainingSeconds: Int {
        guard !exercises.isEmpty, state != .completed else { return 0 }
        var estimate = 0

        let firstFuture: (Int, Int)
        switch state {
        case .ready:
            firstFuture = (exerciseIndex, currentSet)
        case .resting:
            estimate += remainingSeconds
            firstFuture = (exerciseIndex, currentSet)
        case .paused where pausedFromState == .resting:
            estimate += remainingSeconds
            firstFuture = (exerciseIndex, currentSet)
        case .exercising, .paused:
            if currentExercise.durationSeconds != nil {
                estimate += remainingSeconds
            } else {
                let now = pauseStartedAt ?? Date()
                let elapsed = currentSetStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
                let setDuration = TimeInterval(WorkoutTiming.secondsPerSet(for: currentExercise))
                estimate += max(0, Int(ceil(setDuration - elapsed)))
            }
            if isNotFinalSet(exerciseIndex: exerciseIndex, set: currentSet) { estimate += currentExercise.restSeconds }
            firstFuture = nextSetPosition()
        case .completed:
            return 0
        }

        for index in exercises.indices {
            let firstSet = index == firstFuture.0 ? firstFuture.1 : 1
            guard index > firstFuture.0 || (index == firstFuture.0 && firstSet <= exercises[index].sets) else { continue }
            for set in firstSet...exercises[index].sets {
                estimate += WorkoutTiming.secondsPerSet(for: exercises[index])
                if isNotFinalSet(exerciseIndex: index, set: set) { estimate += exercises[index].restSeconds }
            }
        }
        return max(estimate, remainingSeconds)
    }

    private func nextSetPosition() -> (Int, Int) {
        if currentSet < currentExercise.sets { return (exerciseIndex, currentSet + 1) }
        if exerciseIndex + 1 < exercises.count { return (exerciseIndex + 1, 1) }
        return (exercises.count, 1)
    }

    private func isNotFinalSet(exerciseIndex: Int, set: Int) -> Bool {
        if exerciseIndex < exercises.count - 1 { return true }
        return set < exercises[exerciseIndex].sets
    }

    private func setOvertimeSeconds(at date: Date) -> Int {
        guard currentExercise.durationSeconds == nil else { return 0 }
        let elapsed = currentSetStartedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0
        let estimatedSetDuration = WorkoutTiming.secondsPerSet(for: currentExercise)
        return max(0, Int(elapsed) - estimatedSetDuration)
    }

    private static func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }

}
