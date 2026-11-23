import Foundation
import HealthKit
import Observation

@MainActor @Observable
final class WatchWorkoutModel {
    private let health = WatchWorkoutHealth()
    private let stateURL = WorkoutFiles.location("watch-workouts.json")
    private let catalogURL = WorkoutFiles.location("watch-catalog.json")
    private var storage = WatchWorkoutStorage()
    private var expiration: Task<Void, Never>?
    private var recovered = false
    private var catalog: RoutineCatalog?
    private var storageReadable = true

    private(set) var palette = UserDefaults.standard.string(forKey: WorkoutAppearanceSync.paletteKey)
        .flatMap(AppPalette.init(rawValue:)) ?? .terracotta

    private var healthMode = UserDefaults.standard.data(forKey: WorkoutHealthPreferenceSync.contextKey)
        .flatMap { try? JSONDecoder().decode(WatchWorkoutHealthMode.self, from: $0) } ?? .withoutAppleHealth
    private(set) var resultEnergy: Double?
    private(set) var busy = true
    private(set) var showingResult = false
    var error: String?

    var routines: [Routine] { catalog?.routines ?? [] }
    var hasCatalog: Bool { catalog != nil }
    var active: WatchWorkoutState? { storage.active }
    var result: WatchWorkoutResult? { storage.results.last }
    var pending: [WorkoutHistoryRecord] {
        storage.results.filter { !$0.synced && $0.health != .saving }.map(\.record)
    }
    var onPendingChange: (() -> Void)?
    var onLiveWorkoutChange: ((LiveWorkoutSnapshot?) -> Void)?
    var requestStart: (UUID) async -> WatchWorkoutHealthMode? = { _ in nil }
    var cancelStart: () -> Void = {}
    private(set) var startNeedsRetry = false
    private var startID: UUID?

    func cancelPendingStart() {
        guard active == nil, startID != nil else { return }
        startID = nil
        startNeedsRetry = false
        cancelStart()
    }

    init() {
        do {
            let data = try Data(contentsOf: stateURL)
            storage = try JSONDecoder().decode(WatchWorkoutStorage.self, from: data)
            if let active = storage.active, active.setStartedAt == nil {
                storage.active?.setStartedAt = active.pausedAt ?? .now
            }
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

    func receiveHealthPreference(_ data: Data) {
        guard let mode = try? JSONDecoder().decode(WatchWorkoutHealthMode.self, from: data),
              mode != healthMode else { return }
        UserDefaults.standard.set(data, forKey: WorkoutHealthPreferenceSync.contextKey)
        healthMode = mode
    }

    func cancelLegacyExerciseSelection(using enqueue: (UUID) -> Bool) {
        guard let requestID = storage.exerciseSelection?.request.id, enqueue(requestID) else { return }
        clearLegacyExerciseSelection(requestID: requestID)
    }

    func clearLegacyExerciseSelection(requestID: UUID) {
        guard storage.exerciseSelection?.request.id == requestID else { return }
        var updated = storage
        updated.exerciseSelection = nil
        persist(updated)
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

    func start(routineID: String, onStarted: () -> Void) async {
        guard !busy, active == nil,
              let routine = routines.first(where: { $0.id == routineID }),
              !routine.exercises.isEmpty else { return }
        busy = true
        defer { busy = false; refresh() }

        let id = startID ?? UUID()
        startID = id
        startNeedsRetry = false
        let approval = await requestStart(id)
        guard startID == id else { return }
        guard let mode = approval else {
            startNeedsRetry = true
            return
        }
        defer {
            startID = nil
            cancelStart()
        }
        let category = mode.activityCategory
        if category != nil { await health.requestAccessIfNeeded() }
        guard startID == id else { return }
        var preparedRoutine = routine

        let recordingCategory = health.canSave ? category : nil
        preparedRoutine.activityCategory = recordingCategory
        let status: WatchHealthStatus
        if recordingCategory != nil {
            status = .recording
        } else {
            status = category == nil ? .off : .failed
        }
        let active = WatchWorkoutState(id: id, routine: preparedRoutine, startedAt: .now, health: status)
        var updated = storage
        updated.active = active
        guard persist(updated) else {
            if !storageReadable {
                error = "Couldn’t save your workout on this Apple Watch."
            }
            return
        }
        onStarted()
        if let recordingCategory {
            do { try await health.start(category: recordingCategory, id: active.id, at: active.startedAt) }
            catch { recordingFailed() }
        }
    }

    func refresh() {
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

    func applyLiveWorkoutAction(_ action: LiveWorkoutAction) {
        switch action {
        case .pause, .resume: togglePause()
        case .finishSet: finishSet()
        case .skipRest: nextSet()
        case .discard: discard()
        }
    }

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
            onLiveWorkoutChange?(active?.liveWorkout)
            return true
        } catch {
            self.error = "Couldn’t save your workout on this Apple Watch."
            return false
        }
    }
}
