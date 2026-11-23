import Combine
import Foundation
import OSLog
import WatchConnectivity

@MainActor
final class PhoneWorkoutSync: NSObject, WCSessionDelegate {
    private let library: WorkoutLibraryStore
    private let history: WorkoutHistoryStore
    private let logger = Logger(subsystem: "ModiFiT", category: "WatchSync")
    private var libraryChanges: AnyCancellable?
    private var catalogNeedsSending = true
    private var palette: AppPalette?
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
            guard case .completed(let record) = WorkoutSyncMessage.decode(data) else { return }
            do {
                try self.history.importCompletedWorkout(record)
                WorkoutSyncMessage.imported(record.id).enqueue(on: .default)
            } catch {
                self.logger.error("Could not import Apple Watch workout.")
            }
        }
    }
}
