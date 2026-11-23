import Foundation
import HealthKit
import Observation

@MainActor @Observable
final class WatchWorkoutModel {
    private let health = WatchWorkoutHealth()
    private let stateURL = WorkoutFiles.location("watch-workouts.json")
    private let catalogURL = WorkoutFiles.location("watch-catalog.json")
    private let preference = "modifit.watch.saveToHealth"
    private var storage = WatchWorkoutStorage()
    private var expiration: Task<Void, Never>?
    private var recovered = false
    private var catalog: RoutineCatalog?
    private var storageReadable = true

    private(set) var palette = UserDefaults.standard.string(forKey: WorkoutAppearanceSync.paletteKey)
        .flatMap(AppPalette.init(rawValue:)) ?? .terracotta

    private(set) var savesToHealth = false
    private(set) var authorizingHealth = false
    private(set) var resultEnergy: Double?
    private(set) var busy = true
    private(set) var showingResult = false
    var error: String?

    var routines: [Routine] { catalog?.routines ?? [] }
    var exerciseSelectionState: WatchExerciseSelectionState? { storage.exerciseSelection }
    var hasCatalog: Bool { catalog != nil }
    var active: WatchWorkoutState? { storage.active }
    var result: WatchWorkoutResult? { storage.results.last }
    var healthAvailable: Bool { health.isAvailable }
    var pending: [WorkoutHistoryRecord] {
        storage.results.filter { !$0.synced && $0.health != .saving }.map(\.record)
    }
    var onPendingChange: (() -> Void)?
    var onExerciseSelectionRequest: ((WatchExerciseSelectionRequest) -> Bool)?
    var onExerciseSelectionCancellation: ((UUID) -> Void)?

    init() {
        do {
            let data = try Data(contentsOf: stateURL)
            storage = try JSONDecoder().decode(WatchWorkoutStorage.self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // A fresh installation has no workout state.
        } catch {
            storageReadable = false
            self.error = "Couldn’t load your workouts."
        }
        if let data = try? Data(contentsOf: catalogURL),
           let decoded = try? JSONDecoder().decode(RoutineCatalog.self, from: data), decoded.isValid {
            catalog = decoded
        }
        refreshHealthPreference()
        health.onFailure = { [weak self] in self?.recordingFailed() }
    }

    func receivePalette(_ rawValue: String) {
        guard let palette = AppPalette(rawValue: rawValue), palette != self.palette else { return }
        self.palette = palette
        UserDefaults.standard.set(rawValue, forKey: WorkoutAppearanceSync.paletteKey)
    }

    func receiveCatalog(_ data: Data) {
        do {
            let incoming = try JSONDecoder().decode(RoutineCatalog.self, from: data)
            guard incoming.isValid else { return }
            if let catalog, incoming.installationID == catalog.installationID, incoming.revision <= catalog.revision { return }
            try WorkoutFiles.write(incoming, to: catalogURL)
            catalog = incoming
        } catch {
            self.error = "Couldn’t sync routines from iPhone."
        }
    }

    @discardableResult
    func requestExerciseSelection(for routine: Routine) -> Bool {
        guard !busy, !routine.exercises.isEmpty else { return false }
        guard let onExerciseSelectionRequest else {
            error = "Couldn’t reach ModiFiT on iPhone."
            return false
        }
        let request = WatchExerciseSelectionRequest(routineID: routine.id)
        var updated = storage
        updated.exerciseSelection = WatchExerciseSelectionState(request: request, selectedExerciseIDs: nil)
        guard persist(updated) else { return false }
        guard onExerciseSelectionRequest(request) else {
            var cleared = storage
            cleared.exerciseSelection = nil
            persist(cleared)
            error = "Couldn’t reach ModiFiT on iPhone."
            return false
        }
        return true
    }

    func receiveExerciseSelection(_ response: WatchExerciseSelectionResponse) {
        guard var selection = storage.exerciseSelection,
              selection.request.id == response.requestID else { return }
        guard let routine = routines.first(where: { $0.id == selection.request.routineID }) else {
            clearInvalidExerciseSelection("This routine is no longer available on Apple Watch.")
            return
        }
        let selectedIDs = Set(response.selectedExerciseIDs)
        let availableIDs = Set(routine.exercises.map(\.id))
        guard !selectedIDs.isEmpty,
              selectedIDs.count == response.selectedExerciseIDs.count,
              selectedIDs.isSubset(of: availableIDs) else {
            clearInvalidExerciseSelection("The exercise selection from iPhone wasn’t valid.")
            return
        }
        selection.selectedExerciseIDs = response.selectedExerciseIDs
        var updated = storage
        updated.exerciseSelection = selection
        persist(updated)
    }

    func cancelExerciseSelection() {
        guard let selection = storage.exerciseSelection else { return }
        var updated = storage
        updated.exerciseSelection = nil
        guard persist(updated) else { return }
        onExerciseSelectionCancellation?(selection.request.id)
    }

    func clearExerciseSelection() {
        cancelExerciseSelection()
    }

    func receiveExerciseSelectionCancelled(requestID: UUID) {
        guard storage.exerciseSelection?.request.id == requestID else { return }
        var updated = storage
        updated.exerciseSelection = nil
        persist(updated)
    }

    func receiveExerciseSelectionUnavailable(requestID: UUID) {
        guard storage.exerciseSelection?.request.id == requestID else { return }
        var updated = storage
        updated.exerciseSelection = nil
        persist(updated)
        error = "This routine isn’t available on iPhone."
    }

    private func clearInvalidExerciseSelection(_ message: String) {
        var updated = storage
        updated.exerciseSelection = nil
        persist(updated)
        error = message
    }

    func acknowledge(_ id: UUID) {
        guard let index = storage.results.firstIndex(where: { $0.record.id == id && !$0.synced }) else { return }
        var updated = storage
        updated.results[index].synced = true
        persist(updated)
    }

    func recover() async {
        guard !recovered else { return }
        recovered = true
        let expected = active?.health == .recording ? active?.id : nil
        let restored = await health.recover(expectedID: expected)
        if let active, expected != nil {
            if restored {
                health.setPaused(active.pausedAt != nil)
            } else {
                recordingFailed()
            }
        }
        for result in storage.results where result.health == .saving {
            let workout = await health.savedWorkout(id: result.record.id)
            resolveHealth(id: result.record.id, workout: workout)
            showingResult = true
        }
        if let id = result?.record.id, result?.health == .saved {
            resultEnergy = await health.savedWorkout(id: id).flatMap(WatchWorkoutHealth.energy)
        }
        busy = false
        onPendingChange?()
        refresh()
    }

    func refreshHealthPreference() {
        savesToHealth = UserDefaults.standard.bool(forKey: preference) && health.canSave
    }

    func setHealthEnabled(_ enabled: Bool) async {
        guard !authorizingHealth else { return }
        authorizingHealth = true
        defer { authorizingHealth = false }
        if enabled {
            guard health.isAvailable else { return }
            do {
                try await health.authorize()
                guard health.canSave else { error = "Review ModiFiT’s workout permissions in Apple Health."; return }
            } catch {
                self.error = "Couldn’t connect to Apple Health."
                return
            }
        }
        UserDefaults.standard.set(enabled, forKey: preference)
        refreshHealthPreference()
    }

    func start(_ routine: Routine, category: WorkoutActivityCategory?, onStarted: () -> Void) async {
        guard !busy, active == nil, !routine.exercises.isEmpty else { return }
        busy = true
        defer { busy = false; refresh() }
        refreshHealthPreference()
        let shouldRecord = savesToHealth && category != nil
        let active = WatchWorkoutState(routine: routine, startedAt: .now, health: shouldRecord ? .recording : .off)
        var updated = storage
        updated.active = active
        updated.exerciseSelection = nil
        guard persist(updated) else {
            if !storageReadable {
                error = "Couldn’t save your workout on this Apple Watch."
            }
            return
        }
        onStarted()
        if shouldRecord, let category {
            do { try await health.start(category: category, id: active.id, at: active.startedAt) }
            catch { recordingFailed() }
        }
    }

    func refresh() {
        refreshHealthPreference()
        expiration?.cancel()
        expiration = nil
        guard !busy, let active, !active.resting, active.pausedAt == nil, let deadline = active.deadline else { return }
        if deadline <= .now {
            finishSet(at: deadline)
        } else {
            expiration = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow))) } catch { return }
                self?.refresh()
            }
        }
    }

    func finishSet() { finishSet(at: .now) }

    private func finishSet(at end: Date) {
        guard !busy, var active, !active.resting, active.pausedAt == nil else { return }
        let complete = active.finishSet(at: end, nextSetStartsAt: .now)
        var updated = storage
        if complete {
            let result = active.completed(at: end)
            updated.active = nil
            updated.results.removeAll { $0.synced }
            updated.results.append(result)
            guard persist(updated) else { return }
            expiration?.cancel()
            resultEnergy = nil
            showingResult = true
            if result.health == .saving {
                busy = true
                Task {
                    let workout = try? await health.finish(at: end)
                    resolveHealth(id: active.id, workout: workout)
                    busy = false
                    onPendingChange?()
                }
            } else {
                onPendingChange?()
            }
        } else {
            updated.active = active
            if persist(updated) { refresh() }
        }
    }

    func nextSet() {
        guard !busy, var active, active.resting, active.pausedAt == nil else { return }
        active.startSet(at: .now)
        var updated = storage
        updated.active = active
        if persist(updated) { refresh() }
    }

    func togglePause() {
        guard !busy, var active else { return }
        active.togglePause(at: .now)
        var updated = storage
        updated.active = active
        guard persist(updated) else { return }
        health.setPaused(active.pausedAt != nil)
        refresh()
    }

    func discard() {
        guard !busy else { return }
        var updated = storage
        updated.active = nil
        guard persist(updated) else { return }
        expiration?.cancel()
        health.discard()
    }

    func dismissResult() { showingResult = false }

    private func recordingFailed() {
        guard var active, active.health == .recording else { return }
        health.discard()
        active.health = .failed
        var updated = storage
        updated.active = active
        persist(updated)
    }

    private func resolveHealth(id: UUID, workout: HKWorkout?) {
        guard let index = storage.results.firstIndex(where: { $0.record.id == id }) else { return }
        var updated = storage
        updated.results[index].record.healthWorkoutID = workout?.uuid
        if result?.record.id == id { resultEnergy = workout.flatMap(WatchWorkoutHealth.energy) }
        updated.results[index].health = workout == nil ? .failed : .saved
        persist(updated)
    }

    @discardableResult
    private func persist(_ updated: WatchWorkoutStorage) -> Bool {
        do {
            guard storageReadable else { return false }
            try WorkoutFiles.write(updated, to: stateURL)
            storage = updated
            return true
        } catch {
            self.error = "Couldn’t save your workout on this Apple Watch."
            return false
        }
    }
}
