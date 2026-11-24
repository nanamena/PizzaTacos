import ActivityKit
import AppIntents
import Foundation
import OSLog

nonisolated struct WorkoutActivityAttributes: ActivityAttributes, Equatable {
    struct ContentState: Codable, Hashable {
        let revision: Int
        let exerciseName: String
        let exerciseIndex: Int
        let exerciseCount: Int
        let setNumber: Int
        let setsInExercise: Int
        let isResting: Bool
        let pausedAt: Date?
        let timerStartAt: Date
        let deadline: Date?
        let canAdvance: Bool
        let lightButtonColor: UInt32
        let darkButtonColor: UInt32
        let lightKeylineColor: UInt32
        let darkKeylineColor: UInt32

        private enum CodingKeys: String, CodingKey {
            case revision
            case exerciseName
            case exerciseIndex
            case exerciseCount
            case setNumber
            case setsInExercise
            case isResting
            case pausedAt
            case timerStartAt
            case deadline
            case canAdvance
            case lightButtonColor
            case darkButtonColor
            case lightKeylineColor
            case darkKeylineColor
        }

        init(
            revision: Int,
            exerciseName: String,
            exerciseIndex: Int,
            exerciseCount: Int,
            setNumber: Int,
            setsInExercise: Int,
            isResting: Bool,
            pausedAt: Date?,
            timerStartAt: Date,
            deadline: Date?,
            canAdvance: Bool,
            lightButtonColor: UInt32,
            darkButtonColor: UInt32,
            lightKeylineColor: UInt32,
            darkKeylineColor: UInt32
        ) {
            self.revision = revision
            self.exerciseName = exerciseName
            self.exerciseIndex = exerciseIndex
            self.exerciseCount = exerciseCount
            self.setNumber = setNumber
            self.setsInExercise = setsInExercise
            self.isResting = isResting
            self.pausedAt = pausedAt
            self.timerStartAt = timerStartAt
            self.deadline = deadline
            self.canAdvance = canAdvance
            self.lightButtonColor = lightButtonColor
            self.darkButtonColor = darkButtonColor
            self.lightKeylineColor = lightKeylineColor
            self.darkKeylineColor = darkKeylineColor
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            revision = try container.decode(Int.self, forKey: .revision)
            exerciseName = try container.decode(String.self, forKey: .exerciseName)
            exerciseIndex = try container.decode(Int.self, forKey: .exerciseIndex)
            exerciseCount = try container.decode(Int.self, forKey: .exerciseCount)
            setNumber = try container.decode(Int.self, forKey: .setNumber)
            setsInExercise = try container.decode(Int.self, forKey: .setsInExercise)
            isResting = try container.decode(Bool.self, forKey: .isResting)
            pausedAt = try container.decodeIfPresent(Date.self, forKey: .pausedAt)
            timerStartAt = try container.decode(Date.self, forKey: .timerStartAt)
            deadline = try container.decodeIfPresent(Date.self, forKey: .deadline)
            canAdvance = try container.decode(Bool.self, forKey: .canAdvance)
            lightButtonColor = try container.decode(UInt32.self, forKey: .lightButtonColor)
            darkButtonColor = try container.decode(UInt32.self, forKey: .darkButtonColor)
            lightKeylineColor = try container.decodeIfPresent(UInt32.self, forKey: .lightKeylineColor) ?? lightButtonColor
            darkKeylineColor = try container.decodeIfPresent(UInt32.self, forKey: .darkKeylineColor) ?? darkButtonColor
        }
    }

    let workoutID: UUID
    let sourceID: UUID
    let routineName: String
    let isWatchWorkout: Bool
}

struct AdvanceWorkoutIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Advance Workout"
    static var isDiscoverable = false
    static let supportedModes: IntentModes = .background

    typealias ActionHandler = @MainActor @Sendable (UUID, UUID, Int) async -> Bool
    static let actionDependencyKey = "com.vincenzo-coppola.modifit.workout-live-activity.action"

    @Parameter(title: "Workout ID") var workoutID: String
    @Parameter(title: "Source ID") var sourceID: String
    @Parameter(title: "Revision") var revision: Int
    @Dependency(key: AdvanceWorkoutIntent.actionDependencyKey)
    private var actionHandler: ActionHandler

    init() {}

    init(workoutID: UUID, sourceID: UUID, revision: Int) {
        self.workoutID = workoutID.uuidString
        self.sourceID = sourceID.uuidString
        self.revision = revision
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let logger = Logger(subsystem: "ModiFiT", category: "LiveActivityAction")
        logger.info("Received Live Activity workout action.")
        guard let workoutID = UUID(uuidString: workoutID),
              let sourceID = UUID(uuidString: sourceID),
              revision >= 0 else {
            logger.error("Live Activity workout action has invalid parameters.")
            throw AdvanceWorkoutIntentError.actionUnavailable
        }

        guard await actionHandler(workoutID, sourceID, revision) else {
            throw AdvanceWorkoutIntentError.actionUnavailable
        }
        return .result()
    }
}

private enum AdvanceWorkoutIntentError: LocalizedError {
    case actionUnavailable

    var errorDescription: String? { "The workout changed. Try again." }
}
