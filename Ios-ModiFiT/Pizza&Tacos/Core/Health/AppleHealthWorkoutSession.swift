import Foundation
import HealthKit

@MainActor
final class AppleHealthWorkoutSession {
    private let store: HKHealthStore
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    init() {
        store = AppleHealthAccess.shared.store
    }

    func start(category: WorkoutActivityCategory, recordID: UUID) async throws -> Date {
        await AppleHealthAccess.shared.discardInterruptedWorkoutIfNeeded()
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = category.healthKitType

        let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
        self.session = session
        self.builder = builder

        do {
            session.prepare()
            let startDate = Date()
            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)
            try await builder.addMetadata([
                HKMetadataKeySyncIdentifier: "modifit.workout.\(recordID.uuidString)",
                HKMetadataKeySyncVersion: NSNumber(value: 1)
            ])
            return startDate
        } catch {
            discard()
            throw error
        }
    }

    func pause() {
        session?.pause()
    }

    func resume() {
        session?.resume()
    }

    func finish(at endDate: Date) async throws -> HKWorkout {
        guard let session, let builder else { throw SessionError.notRunning }
        session.stopActivity(with: endDate)

        for _ in 0..<50 {
            if session.state == .stopped { break }
            if session.state == .ended { throw SessionError.endedBeforeSave }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard session.state == .stopped else { throw SessionError.stopTimedOut }

        do {
            try await builder.endCollection(at: endDate)
            guard let workout = try await builder.finishWorkout() else {
                throw SessionError.noSavedWorkout
            }
            session.end()
            self.session = nil
            self.builder = nil
            return workout
        } catch {
            discard()
            throw error
        }
    }

    func discard() {
        builder?.discardWorkout()
        session?.end()
        builder = nil
        session = nil
    }

    static func activeEnergyKilocalories(from workout: HKWorkout) -> Double? {
        workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?
            .doubleValue(for: .largeCalorie())
    }

    private enum SessionError: Error {
        case notRunning
        case endedBeforeSave
        case stopTimedOut
        case noSavedWorkout
    }
}
