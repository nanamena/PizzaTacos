import Combine
import HealthKit

@MainActor
final class AppleHealthAccess: ObservableObject {
    static let shared = AppleHealthAccess()

    @Published private(set) var isAvailable = HKHealthStore.isHealthDataAvailable()
    @Published private(set) var canWriteWorkouts = false

    let store = HKHealthStore()
    private let workoutType = HKObjectType.workoutType()
    private var recoveryTask: Task<Void, Never>?

    private init() {
        refresh()
    }

    func refresh() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
        canWriteWorkouts = isAvailable && store.authorizationStatus(for: workoutType) == .sharingAuthorized
    }

    @discardableResult
    func requestAccess() async -> Bool {
        refresh()
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(
                toShare: [workoutType],
                read: [workoutType, HKQuantityType(.activeEnergyBurned)]
            )
        } catch {
            refresh()
            return false
        }
        refresh()
        return canWriteWorkouts
    }

    // The app has no restored exercise state after a crash, so an orphaned live
    // HealthKit workout must not keep recording or be presented as completed.
    func discardInterruptedWorkoutIfNeeded() async {
        if let recoveryTask {
            await recoveryTask.value
            return
        }
        let task = Task {
            guard HKHealthStore.isHealthDataAvailable() else { return }
            if let recovered = try? await store.recoverActiveWorkoutSession() {
                recovered.associatedWorkoutBuilder().discardWorkout()
                recovered.end()
            }
        }
        recoveryTask = task
        await task.value
    }

    func activeEnergyByWorkoutID(_ workoutIDs: [UUID]) async throws -> [UUID: Double] {
        guard isAvailable, !workoutIDs.isEmpty else { return [:] }
        let workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let predicate = HKQuery.predicateForObjects(with: Set(workoutIDs))
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate,
                                      limit: workoutIDs.count, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKWorkout] ?? [])
                }
            }
            store.execute(query)
        }
        return Dictionary(uniqueKeysWithValues: workouts.compactMap { workout in
            AppleHealthWorkoutSession.activeEnergyKilocalories(from: workout).map { (workout.uuid, $0) }
        })
    }
}
