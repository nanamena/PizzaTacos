import Foundation
import WatchConnectivity
import WatchKit

@MainActor
final class WatchAppDelegate: NSObject, WKApplicationDelegate, WCSessionDelegate {
    let model = WatchWorkoutModel()
    private var refreshTasks: [WKWatchConnectivityRefreshBackgroundTask] = []
    private var observations: [NSKeyValueObservation] = []
    private var started = false

    func applicationDidFinishLaunching() { start() }

    func start() {
        guard !started else { return }
        started = true
        model.onPendingChange = { [weak self] in self?.sendPending() }
        if WCSession.isSupported() {
            let session = WCSession.default
            observations = [
                session.observe(\.hasContentPending) { [weak self] _, _ in
                    Task { @MainActor in self?.completeRefreshTasks() }
                },
                session.observe(\.activationState) { [weak self] _, _ in
                    Task { @MainActor in self?.completeRefreshTasks() }
                }
            ]
            session.delegate = self
            session.activate()
        }
        handleActiveWorkoutRecovery()
    }

    func handleActiveWorkoutRecovery() {
        Task { await model.recover() }
    }

    func applicationDidBecomeActive() {
        model.refresh()
        sendPending()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let task = task as? WKWatchConnectivityRefreshBackgroundTask {
                refreshTasks.append(task)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
        completeRefreshTasks()
    }

    func sendPending() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isCompanionAppInstalled else { return }
        for record in model.pending {
            WorkoutSyncMessage.completed(record).enqueue(on: session)
        }
    }

    private func completeRefreshTasks() {
        let session = WCSession.default
        guard session.activationState != .activated || !session.hasContentPending else { return }
        refreshTasks.forEach { $0.setTaskCompletedWithSnapshot(false) }
        refreshTasks.removeAll()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if activationState == .activated { self.applyLatestContext() }
            self.sendPending()
            self.completeRefreshTasks()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in self.sendPending() }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let localURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        do { try FileManager.default.moveItem(at: file.fileURL, to: localURL) }
        catch { return }
        Task { @MainActor in
            defer {
                try? FileManager.default.removeItem(at: localURL)
                self.completeRefreshTasks()
            }
            if let data = try? Data(contentsOf: localURL) { self.model.receiveCatalog(data) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.applyLatestContext()
            self.completeRefreshTasks()
        }
    }

    private func applyLatestContext() {
        let context = WCSession.default.receivedApplicationContext
        if let palette = context[WorkoutAppearanceSync.paletteKey] as? String { model.receivePalette(palette) }
        if let catalog = context["routineCatalog"] as? Data { model.receiveCatalog(catalog) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo["workout"] as? Data else { return }
        Task { @MainActor in
            if case .imported(let id) = WorkoutSyncMessage.decode(data) {
                self.model.acknowledge(id)
            }
            self.completeRefreshTasks()
        }
    }
}
