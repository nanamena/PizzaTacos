import Foundation
import WatchConnectivity

enum WorkoutAppearanceSync {
    static let paletteKey = "workoutPalette"
}

enum WorkoutHealthPreferenceSync {
    static let contextKey = "workoutHealthPreference"
}

struct RoutineCatalog: Codable {
    var version = 1
    let installationID: UUID
    let revision: Int
    let routines: [Routine]

    var isValid: Bool {
        version == 1 && revision > 0 && Set(routines.map(\.id)).count == routines.count
            && routines.allSatisfy { routine in
                Set(routine.exercises.map(\.id)).count == routine.exercises.count
                    && routine.exercises.allSatisfy {
                        $0.sets > 0 && $0.restSeconds >= 0 && ($0.durationSeconds ?? 0) >= 0
                    }
            }
    }
}

struct WatchExerciseSelectionRequest: Codable, Identifiable, Hashable {
    let id: UUID
    let routineID: String
    let supportsHealthMode: Bool?

    init(id: UUID = UUID(), routineID: String) {
        self.id = id
        self.routineID = routineID
        supportsHealthMode = true
    }
}

enum WatchWorkoutHealthMode: Codable, Hashable {
    case withoutAppleHealth
    case appleHealth(WorkoutActivityCategory)

    var activityCategory: WorkoutActivityCategory? {
        if case .appleHealth(let category) = self { return category }
        return nil
    }
}

struct WatchExerciseSelectionResponse: Codable, Hashable {
    let requestID: UUID
    let selectedExerciseIDs: [String]
    let healthMode: WatchWorkoutHealthMode?
}

struct WatchExerciseSelectionState: Codable, Hashable {
    let request: WatchExerciseSelectionRequest
    var selectedExerciseIDs: [String]?
    var healthMode: WatchWorkoutHealthMode?
}

enum WorkoutSyncMessage: Codable {
    case completed(WorkoutHistoryRecord)
    case imported(UUID)
    case watchExerciseSelectionRequested(WatchExerciseSelectionRequest)
    case watchExerciseSelectionSubmitted(WatchExerciseSelectionResponse)
    case watchExerciseSelectionCancelled(UUID)
    case watchExerciseSelectionUnavailable(UUID)

    private struct Envelope: Codable {
        let version: Int
        let message: WorkoutSyncMessage
    }

    static func decode(_ data: Data) -> Self? {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.version == 1 else { return nil }
        return envelope.message
    }

    @discardableResult
    func enqueue(on session: WCSession) -> Bool {
        guard session.activationState == .activated,
              let data = try? JSONEncoder().encode(Envelope(version: 1, message: self))
        else { return false }
        if session.outstandingUserInfoTransfers.contains(where: { transfer in
            guard let payload = transfer.userInfo["workout"] as? Data else { return false }
            return Self.decode(payload)?.deduplicationKey == deduplicationKey
        }) { return true }

        session.transferUserInfo(["workout": data])
        return true
    }

    var identifier: UUID {
        switch self {
        case .completed(let record): record.id
        case .imported(let id): id
        case .watchExerciseSelectionRequested(let request): request.id
        case .watchExerciseSelectionSubmitted(let response): response.requestID
        case .watchExerciseSelectionCancelled(let id), .watchExerciseSelectionUnavailable(let id): id
        }
    }

    private var deduplicationKey: String {
        switch self {
        case .completed(let record): "completed:\(record.id)"
        case .imported(let id): "imported:\(id)"
        case .watchExerciseSelectionRequested(let request): "selection-request:\(request.id)"
        case .watchExerciseSelectionSubmitted(let response): "selection-submitted:\(response.requestID)"
        case .watchExerciseSelectionCancelled(let id): "selection-cancelled:\(id)"
        case .watchExerciseSelectionUnavailable(let id): "selection-unavailable:\(id)"
        }
    }
}

enum WorkoutFiles {
    static func location(_ name: String) -> URL {
        URL.applicationSupportDirectory.appending(path: "ModiFiT").appending(path: name)
    }

    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
