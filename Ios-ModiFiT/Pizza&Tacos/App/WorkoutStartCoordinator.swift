import Foundation

@MainActor
final class WorkoutStartCoordinator {
    private struct Reservation: Codable {
        let workoutID: UUID
        var watchSource: UUID?
        var watchRevision: Int?
        var healthMode: WatchWorkoutHealthMode?
    }

    private let url: URL
    private var reservation: Reservation?
    private var readable = true

    init(url: URL = WorkoutFiles.location("workout-start-reservation.json")) {
        self.url = url
        do {
            reservation = try JSONDecoder().decode(Reservation?.self, from: Data(contentsOf: url))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
        } catch {
            readable = false
        }
    }

    func recoverPhoneReservation() {
        // The phone doesn't restore workouts after termination. HealthKit cleanup runs first.
        if reservation?.watchSource == nil, reservation != nil { _ = save(nil) }
    }

    func reservePhone(id: UUID) -> Bool {
        guard reservation == nil else { return false }
        return save(Reservation(workoutID: id))
    }

    func releasePhone(id: UUID) {
        guard reservation?.watchSource == nil, reservation?.workoutID == id else { return }
        _ = save(nil)
    }

    func observeWatch(_ peer: LiveWorkoutLink.Publication) {
        guard peer.supportsStartClaim == true else { return }
        if let current = reservation {
            guard current.watchSource == peer.source, let revision = current.watchRevision,
                  peer.revision > revision, peer.workout == nil,
                  peer.startAttempt != current.workoutID else { return }
            _ = save(nil)
        } else if let id = peer.workout?.id {
            // A workout on the Watch may have started before the update.
            _ = save(Reservation(workoutID: id, watchSource: peer.source, watchRevision: peer.revision))
        }
    }

    func reserveWatch(_ peer: LiveWorkoutLink.Publication, healthMode: WatchWorkoutHealthMode) -> WatchWorkoutHealthMode? {
        guard peer.supportsStartClaim == true, peer.workout == nil, let id = peer.startAttempt else { return nil }
        if let reservation {
            guard reservation.workoutID == id, reservation.watchSource == peer.source else { return nil }
            return reservation.healthMode
        }
        let claim = Reservation(workoutID: id, watchSource: peer.source,
                                watchRevision: peer.revision, healthMode: healthMode)
        return save(claim) ? healthMode : nil
    }

    private func save(_ value: Reservation?) -> Bool {
        guard readable else { return false }
        do {
            try WorkoutFiles.write(value, to: url)
            reservation = value
            return true
        } catch {
            return false
        }
    }
}
