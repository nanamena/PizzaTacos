import Foundation
import WatchConnectivity

enum WorkoutAppearanceSync {
    static let paletteKey = "workoutPalette"
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

enum WorkoutSyncMessage: Codable {
    case completed(WorkoutHistoryRecord)
    case imported(UUID)

    private struct Envelope: Codable {
        let version: Int
        let message: WorkoutSyncMessage
    }

    static func decode(_ data: Data) -> Self? {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.version == 1 else { return nil }
        return envelope.message
    }

    func enqueue(on session: WCSession) {
        guard session.activationState == .activated,
              let data = try? JSONEncoder().encode(Envelope(version: 1, message: self)),
              !session.outstandingUserInfoTransfers.contains(where: { transfer in
                  guard let payload = transfer.userInfo["workout"] as? Data else { return false }
                  return Self.decode(payload)?.identifier == identifier
              })
        else { return }
        session.transferUserInfo(["workout": data])
    }

    var identifier: UUID {
        switch self {
        case .completed(let record): record.id
        case .imported(let id): id
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
