import Combine
import Foundation
import OSLog
import WatchConnectivity

@MainActor
final class PhoneWorkoutSync: NSObject, ObservableObject, WCSessionDelegate {
    private let library: WorkoutLibraryStore
    private let history: WorkoutHistoryStore
    private let workoutPreferences: WorkoutPreferencesStore

    private var healthMode: WatchWorkoutHealthMode {
        workoutPreferences.health?.mode ?? .withoutAppleHealth
    }
    private let logger = Logger(subsystem: "ModiFiT", category: "WatchSync")
    private let pendingSelectionKey = "modifit.watchExerciseSelection.pending.v1"
    private var libraryChanges: AnyCancellable?
    private var catalogNeedsSending = true
    private var palette: AppPalette?
    let live = LiveWorkoutLink()
    private let liveActivityController = WorkoutLiveActivityController()
    private let starts = WorkoutStartCoordinator()
    private var preparedToStart = false
    @Published private(set) var workoutStartIssue = false
    private var pendingPhoneStart: Routine?
    @Published private(set) var phoneWorkout: FocusWorkoutViewModel?
    @Published private(set) var pendingWatchExerciseSelectionRequest: WatchExerciseSelectionRequest?
    private var installationID: UUID {
        let defaults = UserDefaults.standard
        let key = "modifit.watchCatalog.installation"
        if let value = defaults.string(forKey: key), let id = UUID(uuidString: value) { return id }
        let id = UUID()
        defaults.set(id.uuidString, forKey: key)
        return id
    }

    init(library: WorkoutLibraryStore, history: WorkoutHistoryStore, workoutPreferences: WorkoutPreferencesStore) {
        self.library = library
        self.history = history
        self.workoutPreferences = workoutPreferences
        super.init()
        live.onConnectionChange = { [weak self] isReachable in
            self?.liveActivityController.remoteReachabilityChanged(isReachable)
        }
        live.onPeerState = { [weak self] peer in
            guard let self else { return }
            self.starts.observeWatch(peer)
            self.liveActivityController.receive(
                peer.workout,
                sourceID: peer.source,
                revision: peer.revision,
                isWatchWorkout: true,
                canAdvance: self.live.isConnected && peer.workout?.pausedAt == nil
            )
        }
        live.onWatchClaim = { [weak self] peer in
            guard let self, self.preparedToStart else { return nil }
            return self.starts.reserveWatch(peer, healthMode: self.healthMode)
        }
        live.onAction = { [weak self] action in self?.phoneWorkout?.applyLiveWorkoutAction(action) }
        live.onClockRefresh = { [weak self] in self?.phoneWorkout?.refreshCountdown() }
        if let snapshot = live.localPublication.workout, snapshot.isValid {
            installPhoneWorkout(FocusWorkoutViewModel(routine: snapshot.routine, historyStore: history, restoring: snapshot))
        } else {
            if live.localPublication.workout != nil { live.publish(nil) }
            liveActivityController.end(sourceID: live.localPublication.source)
        }
        let restoredWorkoutID = phoneWorkout?.workoutID
        Task {
            await AppleHealthAccess.shared.discardInterruptedWorkoutIfNeeded()
            starts.recoverPhoneReservation(activePhoneWorkoutID: restoredWorkoutID)
            preparedToStart = true
        }
        if let data = UserDefaults.standard.data(forKey: pendingSelectionKey) {
            pendingWatchExerciseSelectionRequest = try? JSONDecoder().decode(WatchExerciseSelectionRequest.self, from: data)
        }
        guard WCSession.isSupported() else { return }
        libraryChanges = library.catalogDidChange.sink { [weak self] in
            self?.catalogNeedsSending = true
            self?.sendCatalogIfNeeded()
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func updatePalette(_ palette: AppPalette) {
        self.palette = palette
        liveActivityController.updatePalette(palette)
        sendPaletteIfNeeded()
    }

    func refresh() {
        phoneWorkout?.refreshCountdown()
        sendCatalogIfNeeded()
        sendPaletteIfNeeded()
        syncHealthPreference()
        live.refreshConnection()
    }

    func startPhoneWorkout(_ routine: Routine) {
        guard phoneWorkout == nil, !routine.exercises.isEmpty else { return }
        pendingPhoneStart = routine
        live.receiveContext()
        guard live.remoteWorkout == nil else {
            dismissWorkoutStartIssue()
            return
        }
        let session = WCSession.default
        let canVerifyWatch = !WCSession.isSupported() || (session.activationState == .activated
            && (!session.isPaired || !session.isWatchAppInstalled || live.peerState?.supportsStartClaim == true))
        guard preparedToStart, canVerifyWatch else {
            workoutStartIssue = true
            live.refreshConnection()
            return
        }

        var preparedRoutine = routine
        preparedRoutine.activityCategory = healthMode.activityCategory
        let workout = FocusWorkoutViewModel(routine: preparedRoutine, historyStore: history)
        let id = workout.workoutID
        guard starts.reservePhone(id: id) else {
            workoutStartIssue = true
            live.refreshConnection()
            return
        }
        dismissWorkoutStartIssue()
        installPhoneWorkout(workout)
        Task { await workout.startWorkout() }
    }

    private func installPhoneWorkout(_ workout: FocusWorkoutViewModel) {
        let id = workout.workoutID
        workout.onLiveWorkoutChange = { [weak self, weak workout] snapshot in
            guard let self else { return }
            self.live.publish(snapshot)
            let publication = self.live.localPublication
            self.liveActivityController.receive(
                snapshot,
                sourceID: publication.source,
                revision: publication.revision,
                isWatchWorkout: false,
                canAdvance: true
            )
            if workout?.state == .completed { self.starts.releasePhone(id: id) }
        }
        phoneWorkout = workout
        workout.onLiveWorkoutChange?(workout.liveWorkout)
    }

    func retryWorkoutStart() {
        guard let routine = pendingPhoneStart else { return }
        startPhoneWorkout(routine)
    }

    func hideWorkoutStartIssue() { workoutStartIssue = false }

    func dismissWorkoutStartIssue() {
        pendingPhoneStart = nil
        workoutStartIssue = false
    }

    func dismissPhoneWorkout() {
        guard phoneWorkout?.state == .completed else { return }
        phoneWorkout = nil
    }

    func setAppIsActive(_ isActive: Bool) {
        liveActivityController.setAppIsActive(isActive)
    }

    func advanceWorkout(workoutID: UUID, sourceID: UUID, revision: Int) async -> Bool {
        if live.localPublication.source == sourceID {
            let accepted = advancePhoneWorkout(workoutID: workoutID, revision: revision)
            let logger = Logger(subsystem: "ModiFiT", category: "LiveActivityAction")
            logger.info("Local workout accepted Live Activity action: \(accepted).")
            if !accepted {
                liveActivityController.refreshExistingActivity(for: workoutID)
            }
            await liveActivityController.flushUpdates()
            logger.info("Finished processing Local Workout Live Activity updates.")
            return accepted
        }

        if !live.isConnected {
            _ = await live.refreshConnectionAndWait()
        }
        guard live.isConnected,
              let peer = live.peerState,
              peer.source == sourceID,
              peer.revision == revision,
              let workout = peer.workout,
              workout.id == workoutID,
              workout.pausedAt == nil else { return false }

        let action: LiveWorkoutAction = workout.resting ? .skipRest : .finishSet
        let accepted = await live.sendActionAndWait(action, for: workoutID, expectedRevision: revision)
        await liveActivityController.flushUpdates()
        return accepted
    }

    private func advancePhoneWorkout(workoutID: UUID, revision: Int) -> Bool {
        guard let phoneWorkout, phoneWorkout.workoutID == workoutID else { return false }
        phoneWorkout.refreshCountdown()

        let publication = live.localPublication
        guard publication.revision == revision,
              let workout = publication.workout,
              workout.id == workoutID else { return false }

        let action: LiveWorkoutAction = workout.resting ? .skipRest : .finishSet
        guard action.isAvailable(in: workout) else { return false }
        phoneWorkout.applyLiveWorkoutAction(action)
        return live.localPublication.revision > revision
    }

    @discardableResult
    func submitWatchExerciseSelection(_ response: WatchExerciseSelectionResponse) -> Bool {
        guard let request = pendingWatchExerciseSelectionRequest,
              request.id == response.requestID,
              let routine = library.standaloneRoutines.first(where: { $0.id == request.routineID }) else { return false }
        let selectedIDs = Set(response.selectedExerciseIDs)
        let availableIDs = Set(routine.exercises.map(\.id))
        let session = WCSession.default
        guard !selectedIDs.isEmpty, selectedIDs.count == response.selectedExerciseIDs.count,
              selectedIDs.isSubset(of: availableIDs), session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled else { return false }

        let compatibleResponse = WatchExerciseSelectionResponse(
            requestID: response.requestID,
            selectedExerciseIDs: response.selectedExerciseIDs,
            healthMode: request.supportsHealthMode == true ? healthMode : nil
        )
        guard WorkoutSyncMessage.watchExerciseSelectionSubmitted(compatibleResponse).enqueue(on: session) else { return false }
        setPendingWatchExerciseSelectionRequest(nil)
        return true
    }

    func cancelWatchExerciseSelection(requestID: UUID) {
        guard let request = pendingWatchExerciseSelectionRequest, request.id == requestID else { return }
        if WCSession.default.activationState == .activated {
            WorkoutSyncMessage.watchExerciseSelectionCancelled(requestID).enqueue(on: .default)
        }
        setPendingWatchExerciseSelectionRequest(nil)
    }

    func syncHealthPreference() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled,
              let data = try? JSONEncoder().encode(healthMode) else { return }
        var context = session.applicationContext
        guard context[WorkoutHealthPreferenceSync.contextKey] as? Data != data else { return }
        context[WorkoutHealthPreferenceSync.contextKey] = data
        do {
            try session.updateApplicationContext(context)
        } catch {
            logger.error("Could not sync the Watch Apple Health preference.")
        }
    }

    private func sendPaletteIfNeeded() {
        guard WCSession.isSupported(), let palette else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        var context = session.applicationContext
        guard context[WorkoutAppearanceSync.paletteKey] as? String != palette.rawValue else { return }
        context[WorkoutAppearanceSync.paletteKey] = palette.rawValue
        do {
            try session.updateApplicationContext(context)
        } catch {
            logger.error("Could not sync the Watch palette.")
        }
    }

    private func sendCatalogIfNeeded() {
        guard WCSession.isSupported(), catalogNeedsSending else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        #if !targetEnvironment(simulator)
        guard session.outstandingFileTransfers.isEmpty else { return }
        #endif

        let defaults = UserDefaults.standard
        let key = "modifit.watchCatalog.revision"
        let revision = defaults.integer(forKey: key) + 1
        let catalog = RoutineCatalog(installationID: installationID, revision: revision, routines: library.standaloneRoutines)
        do {
            #if targetEnvironment(simulator)
            // The simulator supports application context but not background file delivery.
            var context = session.applicationContext
            context["routineCatalog"] = try JSONEncoder().encode(catalog)
            try session.updateApplicationContext(context)
            #else
            // Each queued transfer owns its input file until the system finishes reading it.
            let url = WorkoutFiles.location("catalog-transfer-\(UUID().uuidString).json")
            try WorkoutFiles.write(catalog, to: url)
            session.transferFile(url, metadata: nil)
            #endif
            defaults.set(revision, forKey: key)
            catalogNeedsSending = false
        } catch {
            logger.error("Could not prepare workout catalog.")
        }
    }

    private func connectedWatchChanged() {
        catalogNeedsSending = true
        refresh()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in self.connectedWatchChanged() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in self.live.resetPeer() }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.connectedWatchChanged() }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.syncHealthPreference()
            self.live.refreshConnection()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.live.receiveContext() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data,
                             replyHandler: @escaping (Data) -> Void) {
        Task { @MainActor in replyHandler(self.live.reply(to: messageData)) }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
        let failed = error != nil
        Task { @MainActor in
            if failed {
                self.catalogNeedsSending = true
            } else {
                self.sendCatalogIfNeeded()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo["workout"] as? Data else { return }
        Task { @MainActor in
            guard let message = WorkoutSyncMessage.decode(data) else { return }
            switch message {
            case .completed(let record):
                do {
                    try self.history.importCompletedWorkout(record)
                    WorkoutSyncMessage.imported(record.id).enqueue(on: .default)
                } catch {
                    self.logger.error("Could not import Apple Watch workout.")
                }
            case .watchExerciseSelectionRequested(let request):
                self.receiveWatchExerciseSelectionRequest(request)
            case .watchExerciseSelectionCancelled(let requestID):
                guard self.pendingWatchExerciseSelectionRequest?.id == requestID else { return }
                self.setPendingWatchExerciseSelectionRequest(nil)
            default:
                break
            }
        }
    }

    private func receiveWatchExerciseSelectionRequest(_ request: WatchExerciseSelectionRequest) {
        guard library.standaloneRoutines.contains(where: { $0.id == request.routineID }) else {
            WorkoutSyncMessage.watchExerciseSelectionUnavailable(request.id).enqueue(on: .default)
            return
        }
        if let current = pendingWatchExerciseSelectionRequest, current.id != request.id {
            WorkoutSyncMessage.watchExerciseSelectionCancelled(current.id).enqueue(on: .default)
        }
        setPendingWatchExerciseSelectionRequest(request)
    }

    private func setPendingWatchExerciseSelectionRequest(_ request: WatchExerciseSelectionRequest?) {
        pendingWatchExerciseSelectionRequest = request
        guard let request, let data = try? JSONEncoder().encode(request) else {
            UserDefaults.standard.removeObject(forKey: pendingSelectionKey)
            return
        }
        UserDefaults.standard.set(data, forKey: pendingSelectionKey)
    }
}
