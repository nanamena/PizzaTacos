import Foundation
import Combine

// Este ViewModel coordina la sesión, las transiciones entre sets y el temporizador.
@MainActor
final class FocusWorkoutViewModel: ObservableObject {
    @Published private(set) var state: WorkoutSessionState = .ready
    @Published private(set) var exerciseIndex = 0
    @Published private(set) var currentSet = 1
    @Published private(set) var remainingSeconds = 0
    @Published private(set) var countdownDuration = 0
    @Published private(set) var completedExercises = 0
    @Published private(set) var completedSets = 0
    @Published private(set) var sessionDurationSeconds = 0
    @Published var showingEndConfirmation = false
    @Published var showingExitConfirmation = false
    @Published var presentedSheet: FocusWorkoutSheet?
    @Published private(set) var endedEarly = false

    let routine: Routine
    let exercises: [FocusExercise]
    let workoutID = UUID()
    private let historyStore: WorkoutHistoryStore

    private var timerTask: Task<Void, Never>?
    private var countdownDeadline: Date?
    private var activeRestDuration = 0
    private var pausedFromState: WorkoutSessionState = .exercising
    private var sessionStartedAt: Date?
    private var sessionEndedAt: Date?
    private var totalPausedSeconds: TimeInterval = 0
    private var pauseStartedAt: Date?

    init(routine: Routine, historyStore: WorkoutHistoryStore) {
        self.routine = routine
        self.historyStore = historyStore
        exercises = Self.exercises(for: routine).map { exercise in
            FocusExercise(id: exercise.id, name: exercise.name, sets: exercise.sets,
                          repetitions: exercise.repetitions, durationSeconds: exercise.durationSeconds,
                          restSeconds: exercise.restSeconds, symbol: exercise.symbol,
                          muscleGroups: Self.muscleGroups(for: exercise.name))
        }
    }

    var currentExercise: FocusExercise { exercises[min(exerciseIndex, exercises.count - 1)] }
    var currentExerciseNumber: Int { min(exerciseIndex + 1, exercises.count) }
    var pausedStateIsTimedExercise: Bool { pausedFromState == .exercising && currentExercise.durationSeconds != nil }
    var progressLabel: String { "\(completedExercises) of \(exercises.count)" }
    var segmentProgress: Double { Double(completedExercises) / Double(max(exercises.count, 1)) }
    var currentTimeText: String {
        if currentExercise.durationSeconds != nil && (state == .exercising || state == .paused) {
            return Self.timeString(remainingSeconds)
        }
        return currentExercise.repetitions.map { "\($0) reps" } ?? "Exercise"
    }
    var setLabel: String { "Set \(currentSet) of \(currentExercise.sets)" }
    var currentCaloriesText: String { "— kcal" }
    var remainingWorkoutText: String { "≈ \(Self.timeString(estimatedRemainingSeconds))" }
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
    func startWorkout() {
        guard state == .ready else { return }
        sessionStartedAt = Date()
        state = .exercising
        startTimedExerciseIfNeeded()
    }

    // Esta función pausa el estado actual y conserva el tiempo exacto restante.
    func pauseWorkout() {
        guard state == .exercising || state == .resting else { return }
        pausedFromState = state
        if let deadline = countdownDeadline {
            remainingSeconds = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
            timerTask?.cancel()
            timerTask = nil
            countdownDeadline = nil
        }
        pauseStartedAt = Date()
        state = .paused
    }

    // Esta función reanuda el conteo desde la fecha límite restante o el set pausado.
    func resumeWorkout() {
        guard state == .paused else { return }
        if let pauseStartedAt {
            totalPausedSeconds += Date().timeIntervalSince(pauseStartedAt)
        }
        pauseStartedAt = nil
        state = pausedFromState
        if pausedFromState == .resting || currentExercise.durationSeconds != nil {
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
        state = .exercising
        startTimedExerciseIfNeeded()
    }

    // Esta función reinicia el periodo de descanso actual.
    func restartRest() {
        guard state == .resting else { return }
        startCountdown(seconds: activeRestDuration, phase: .resting)
    }

    // Esta función reinicia la sesión desde el primer ejercicio y su primer set.
    func restartWorkout() {
        timerTask?.cancel()
        timerTask = nil
        countdownDeadline = nil
        exerciseIndex = 0
        currentSet = 1
        completedExercises = 0
        completedSets = 0
        totalPausedSeconds = 0
        pauseStartedAt = nil
        sessionStartedAt = Date()
        sessionEndedAt = nil
        endedEarly = false
        state = .exercising
        startTimedExerciseIfNeeded()
    }

    // Esta función termina anticipadamente y detiene cualquier temporizador pendiente.
    func endWorkout() {
        completeWorkout(endedEarly: true)
    }

    // Esta función abre la lista completa sin cambiar el ejercicio activo.
    func showExerciseList() {
        presentedSheet = .exerciseList
    }

    // Esta función muestra detalles de un ejercicio sin alterar el progreso.
    func showDetails(for exercise: FocusExercise) {
        presentedSheet = .exerciseDetail(exercise)
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
                self.remainingSeconds = secondsLeft
                if secondsLeft == 0 {
                    self.timerTask = nil
                    self.countdownDeadline = nil
                    self.countdownFinished(phase: phase)
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    // Esta función transiciona del descanso al ejercicio o completa ejercicios por tiempo.
    private func countdownFinished(phase: WorkoutSessionState) {
        guard state != .paused && state != .completed else { return }
        if phase == .resting {
            state = .exercising
            startTimedExerciseIfNeeded()
        } else if phase == .exercising {
            finishCurrentSet()
        }
    }

    // Esta función inicia un conteo para ejercicios con duración configurada.
    private func startTimedExerciseIfNeeded() {
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
                                                     muscleGroups: Array(Set(exercises.flatMap(\.muscleGroups))).sorted()))
        }
    }

    // Esta propiedad estima el tiempo restante y distingue la duración conocida de las repeticiones.
    private var estimatedRemainingSeconds: Int {
        guard !exercises.isEmpty, state != .completed else { return 0 }
        var estimate = 0
        if state == .resting || (state == .paused && pausedFromState == .resting) {
            estimate += remainingSeconds
        } else if state == .exercising || state == .paused {
            estimate += currentExercise.durationSeconds.map { remainingSeconds > 0 ? remainingSeconds : $0 } ?? 30
            if isNotFinalSet(exerciseIndex: exerciseIndex, set: currentSet) { estimate += currentExercise.restSeconds }
        }

        let firstFuture = state == .resting || (state == .paused && pausedFromState == .resting)
            ? (exerciseIndex, currentSet)
            : nextSetPosition()
        for index in exercises.indices {
            let firstSet = index == firstFuture.0 ? firstFuture.1 : 1
            guard index > firstFuture.0 || (index == firstFuture.0 && firstSet <= exercises[index].sets) else { continue }
            for set in firstSet...exercises[index].sets {
                estimate += exercises[index].durationSeconds ?? 30
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

    private static func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }

    // Esta clasificación permite resumir solo los grupos realmente incluidos en los ejercicios registrados.
    private static func muscleGroups(for name: String) -> [String] {
        let name = name.lowercased()
        if name.contains("bench") || name.contains("push") { return ["Chest", "Arms"] }
        if name.contains("shoulder") { return ["Shoulders", "Arms"] }
        if name.contains("lat") || name.contains("row") || name.contains("deadlift") { return ["Back", "Arms"] }
        if name.contains("curl") || name.contains("tricep") { return ["Arms"] }
        if name.contains("bridge") { return ["Glutes", "Core"] }
        if name.contains("plank") { return ["Core"] }
        if name.contains("squat") || name.contains("lunge") { return ["Legs", "Glutes"] }
        if name.contains("calf") { return ["Legs"] }
        return []
    }

    // Estos ejemplos mantienen ejercicios y cantidades explícitos mientras se conecta el almacenamiento real.
    private static func exercises(for routine: Routine) -> [FocusExercise] {
        switch routine.id {
        case "lower":
            [
                FocusExercise(id: "squat", name: "Goblet Squat", sets: 4, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "figure.strengthtraining.traditional"),
                FocusExercise(id: "deadlift", name: "Romanian Deadlift", sets: 3, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "dumbbell.fill"),
                FocusExercise(id: "lunge", name: "Reverse Lunge", sets: 3, repetitions: 10, durationSeconds: nil, restSeconds: 45, symbol: "figure.walk"),
                FocusExercise(id: "bridge", name: "Glute Bridge", sets: 3, repetitions: 12, durationSeconds: nil, restSeconds: 45, symbol: "figure.core.training"),
                FocusExercise(id: "calf", name: "Calf Raise", sets: 3, repetitions: 15, durationSeconds: nil, restSeconds: 45, symbol: "figure.stand")
            ]
        case "full":
            [
                FocusExercise(id: "press", name: "Bench Press", sets: 4, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "dumbbell.fill"),
                FocusExercise(id: "row", name: "Dumbbell Row", sets: 3, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "dumbbell.fill"),
                FocusExercise(id: "squat", name: "Goblet Squat", sets: 4, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "figure.strengthtraining.traditional"),
                FocusExercise(id: "shoulder", name: "Shoulder Press", sets: 3, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "dumbbell.fill"),
                FocusExercise(id: "bridge", name: "Glute Bridge", sets: 3, repetitions: 12, durationSeconds: nil, restSeconds: 45, symbol: "figure.core.training"),
                FocusExercise(id: "plank", name: "Plank", sets: 3, repetitions: nil, durationSeconds: 30, restSeconds: 45, symbol: "figure.core.training"),
                FocusExercise(id: "curl", name: "Bicep Curl", sets: 3, repetitions: 12, durationSeconds: nil, restSeconds: 45, symbol: "dumbbell.fill"),
                FocusExercise(id: "calf", name: "Calf Raise", sets: 3, repetitions: 15, durationSeconds: nil, restSeconds: 45, symbol: "figure.stand")
            ]
        default:
            [
                FocusExercise(id: "bench", name: "Bench Press", sets: 4, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "dumbbell.fill"),
                FocusExercise(id: "shoulder", name: "Shoulder Press", sets: 3, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "dumbbell.fill"),
                FocusExercise(id: "lat", name: "Lat Pulldown", sets: 3, repetitions: 10, durationSeconds: nil, restSeconds: 60, symbol: "figure.strengthtraining.traditional"),
                FocusExercise(id: "curl", name: "Bicep Curl", sets: 3, repetitions: 12, durationSeconds: nil, restSeconds: 45, symbol: "dumbbell.fill"),
                FocusExercise(id: "tricep", name: "Tricep Extension", sets: 3, repetitions: 12, durationSeconds: nil, restSeconds: 45, symbol: "dumbbell.fill")
            ]
        }
    }
}
