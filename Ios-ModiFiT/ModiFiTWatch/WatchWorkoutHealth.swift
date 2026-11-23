import Foundation
import HealthKit

@MainActor
final class WatchWorkoutHealth: NSObject, HKWorkoutSessionDelegate {
    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var stopped: CheckedContinuation<Bool, Never>?
    private var timeout: Task<Void, Never>?
    var onFailure: (() -> Void)?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var canSave: Bool { isAvailable && store.authorizationStatus(for: .workoutType()) == .sharingAuthorized }

    func authorize() async throws {
        try await store.requestAuthorization(toShare: [.workoutType()], read: [.workoutType(), HKQuantityType(.activeEnergyBurned)])
    }

    func start(category: WorkoutActivityCategory, id: UUID, at date: Date) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = category.healthKitType
        let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
        attach(session)
        do {
            let builder = session.associatedWorkoutBuilder()
            session.startActivity(with: date)
            try await builder.beginCollection(at: date)
            try await builder.addMetadata([
                HKMetadataKeySyncIdentifier: Self.syncID(id),
                HKMetadataKeySyncVersion: NSNumber(value: 1)
            ])
        } catch {
            discard()
            throw error
        }
    }

    func setPaused(_ paused: Bool) {
        if paused { session?.pause() } else { session?.resume() }
    }

    func finish(at date: Date) async throws -> HKWorkout {
        guard let session, let builder else { throw RecordingError.unavailable }
        defer { session.end(); self.session = nil; self.builder = nil }
        do {
            let didStop = await withCheckedContinuation { continuation in
                if session.state == .stopped {
                    continuation.resume(returning: true)
                    return
                }
                stopped = continuation
                timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(8)) } catch { return }
                    self?.resolveStop(false)
                }
                session.stopActivity(with: date)
            }
            guard didStop else { throw RecordingError.unavailable }
            try await builder.endCollection(at: date)
            guard let workout = try await builder.finishWorkout() else { throw RecordingError.unavailable }
            return workout
        } catch {
            builder.discardWorkout()
            throw error
        }
    }

    func discard() {
        builder?.discardWorkout()
        session?.end()
        session = nil
        builder = nil
        resolveStop(false)
    }

    func recover(expectedID: UUID?) async -> Bool {
        guard isAvailable, let recovered = try? await store.recoverActiveWorkoutSession() else { return false }
        attach(recovered)
        guard let expectedID,
              builder?.metadata[HKMetadataKeySyncIdentifier] as? String == Self.syncID(expectedID),
              recovered.state == .running || recovered.state == .paused else {
            discard()
            return false
        }
        return true
    }

    func savedWorkout(id: UUID) async -> HKWorkout? {
        guard isAvailable else { return nil }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [Self.syncID(id)])
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [], limit: 1)
        return try? await descriptor.result(for: store).first
    }

    static func energy(_ workout: HKWorkout) -> Double? {
        workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .largeCalorie())
    }

    private static func syncID(_ id: UUID) -> String { "modifit.workout.\(id.uuidString)" }

    private func attach(_ session: HKWorkoutSession) {
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: session.workoutConfiguration)
        session.delegate = self
        self.session = session
        self.builder = builder
    }

    private func resolveStop(_ success: Bool) {
        timeout?.cancel()
        timeout = nil
        stopped?.resume(returning: success)
        stopped = nil
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        let id = ObjectIdentifier(workoutSession)
        Task { @MainActor in
            guard self.session.map(ObjectIdentifier.init) == id else { return }
            if toState == .stopped { self.resolveStop(true) }
            if toState == .ended { self.resolveStop(false) }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let id = ObjectIdentifier(workoutSession)
        Task { @MainActor in
            guard self.session.map(ObjectIdentifier.init) == id else { return }
            self.resolveStop(false)
            self.onFailure?()
        }
    }

    private enum RecordingError: Error { case unavailable }
}
