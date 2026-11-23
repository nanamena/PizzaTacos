import Combine
import Foundation
import OSLog
import WatchConnectivity

@MainActor
final class PhoneWorkoutSync: NSObject, ObservableObject, WCSessionDelegate {
    private let library: WorkoutLibraryStore
    private let history: WorkoutHistoryStore
    private let logger = Logger(subsystem: "ModiFiT", category: "WatchSync")
    private let pendingSelectionKey = "modifit.watchExerciseSelection.pending.v1"
    private var libraryChanges: AnyCancellable?
    private var catalogNeedsSending = true
    private var palette: AppPalette?
    @Published private(set) var pendingWatchExerciseSelectionRequest: WatchExerciseSelectionRequest?
    private var installationID: UUID {
        let defaults = UserDefaults.standard
        let key = "modifit.watchCatalog.installation"
        if let value = defaults.string(forKey: key), let id = UUID(uuidString: value) { return id }
        let id = UUID()
        defaults.set(id.uuidString, forKey: key)
        return id
    }

    init(library: WorkoutLibraryStore, history: WorkoutHistoryStore) {
        self.library = library
        self.history = history
        super.init()
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
        sendPaletteIfNeeded()
    }

    func refresh() {
        sendCatalogIfNeeded()
        sendPaletteIfNeeded()
    }

    @discardableResult
    func submitWatchExerciseSelection(requestID: UUID, selectedExerciseIDs: [String]) -> Bool {
        guard let request = pendingWatchExerciseSelectionRequest,
              request.id == requestID,
              let routine = library.standaloneRoutines.first(where: { $0.id == request.routineID }) else { return false }
        let selectedIDs = Set(selectedExerciseIDs)
        let availableIDs = Set(routine.exercises.map(\.id))
        let session = WCSession.default
        guard !selectedIDs.isEmpty, selectedIDs.count == selectedExerciseIDs.count,
              selectedIDs.isSubset(of: availableIDs), session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled else { return false }

        WorkoutSyncMessage.watchExerciseSelectionSubmitted(
            WatchExerciseSelectionResponse(requestID: requestID, selectedExerciseIDs: selectedExerciseIDs)
        ).enqueue(on: .default)
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

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.connectedWatchChanged() }
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
