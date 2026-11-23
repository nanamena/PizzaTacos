import Foundation
import Observation
import WatchConnectivity

struct LiveWorkoutSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let routine: Routine
    let position: WorkoutPosition
    let resting: Bool
    let setStartedAt: Date
    let deadline: Date?
    let pausedAt: Date?

    var exercise: FocusExercise { routine.exercises[position.exerciseIndex] }

    var isValid: Bool {
        routine.exercises.indices.contains(position.exerciseIndex)
            && (1...max(1, exercise.sets)).contains(position.set)
            && exercise.sets > 0
            && (!resting || deadline != nil)
    }

    func timerText(at date: Date) -> String {
        let now = pausedAt ?? date
        if let deadline {
            let remaining = deadline.timeIntervalSince(now)
            if resting && remaining <= 0 {
                return "+" + Self.format(seconds: Int(-remaining))
            }
            return Self.format(seconds: max(0, Int(ceil(remaining))))
        }
        return Self.format(seconds: max(0, Int(now.timeIntervalSince(setStartedAt))))
    }

    private static func format(seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

enum LiveWorkoutAction: String, Codable {
    case pause, resume, finishSet, skipRest, discard

    func isAvailable(in workout: LiveWorkoutSnapshot) -> Bool {
        switch self {
        case .pause: workout.pausedAt == nil
        case .resume: workout.pausedAt != nil
        case .finishSet: workout.pausedAt == nil && !workout.resting
        case .skipRest: workout.pausedAt == nil && workout.resting
        case .discard: true
        }
    }
}

@MainActor @Observable
final class LiveWorkoutLink {
    struct Publication: Codable {
        let source: UUID
        let revision: Int
        let workout: LiveWorkoutSnapshot?
        var supportsStartClaim: Bool?
        var startAttempt: UUID?
    }

    private enum Message: Codable {
        case publication(Publication)
        case request
        case claim(Publication)
        case command(UUID, Int, LiveWorkoutAction)
    }

    private struct Reply: Codable {
        let publication: Publication
        let accepted: Bool
        var healthMode: WatchWorkoutHealthMode?
    }

    private static let contextKey = "liveWorkout.v1"
    private static let storageKey = "modifit.liveWorkout.publication.v1"
    private var local: Publication
    private var remote: Publication?
    private var retiredSources: Set<UUID> = []
    private var connectionGeneration = UUID()
    private(set) var isConnected = false
    private(set) var commandPending = false
    private(set) var commandRejected = false
    var onAction: ((LiveWorkoutAction) -> Void)?
    var onClockRefresh: (() -> Void)?

    var remoteWorkout: LiveWorkoutSnapshot? { remote?.workout }
    var hasConflict: Bool { local.workout != nil && remoteWorkout != nil }
    var onPeerState: ((Publication) -> Void)?
    var onWatchClaim: ((Publication) -> WatchWorkoutHealthMode?)?
    var peerState: Publication? { remote }
    private let watchPublicationURL = WorkoutFiles.location("watch-live-publication.json")

    init() {
        let saved = UserDefaults.standard.data(forKey: Self.storageKey)
        #if os(watchOS)
        if let data = try? Data(contentsOf: watchPublicationURL),
           let publication = try? JSONDecoder().decode(Publication.self, from: data) {
            local = publication
            return
        }
        #endif
        local = saved.flatMap { try? JSONDecoder().decode(Publication.self, from: $0) }
            ?? Publication(source: UUID(), revision: 0, workout: nil)
    }

    func publish(_ workout: LiveWorkoutSnapshot?) {
        #if os(watchOS)
        let supportsStartClaim: Bool? = true
        let attempt = workout == nil ? local.startAttempt : nil
        #else
        let supportsStartClaim: Bool? = nil
        let attempt: UUID? = nil
        #endif
        guard local.workout != workout || local.supportsStartClaim != supportsStartClaim
                || local.startAttempt != attempt else { return }
        let publication = Publication(source: local.source, revision: local.revision + 1, workout: workout,
                                      supportsStartClaim: supportsStartClaim, startAttempt: attempt)
        guard commit(publication) else { return }
        sendContext()
        let generation = connectionGeneration
        send(.publication(local)) { [weak self] reply in
            guard let self, self.connectionGeneration == generation, let reply else { return }
            self.receive(reply.publication)
            self.isConnected = self.isReachable
        }
    }

    private func commit(_ publication: Publication) -> Bool {
        #if os(watchOS)
        do { try WorkoutFiles.write(publication, to: watchPublicationURL) }
        catch { return false }
        #else
        guard let data = try? JSONEncoder().encode(publication) else { return false }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        #endif
        local = publication
        return true
    }

    func requestWatchStart(id: UUID) async -> WatchWorkoutHealthMode? {
        guard local.workout == nil,
              local.startAttempt == nil || local.startAttempt == id else { return nil }
        if local.startAttempt == nil {
            let attempt = Publication(source: local.source, revision: local.revision + 1, workout: nil,
                                      supportsStartClaim: true, startAttempt: id)
            guard commit(attempt) else { return nil }
        }
        let publication = local
        let reply = await withCheckedContinuation { continuation in
            send(.claim(publication)) { continuation.resume(returning: $0) }
        }
        if let reply {
            receive(reply.publication)
            isConnected = isReachable
        }
        guard local.startAttempt == id, reply?.accepted == true else { return nil }
        return reply?.healthMode
    }

    func clearWatchStart() {
        guard local.startAttempt != nil else { return }
        let cleared = Publication(source: local.source, revision: local.revision + 1, workout: local.workout,
                                  supportsStartClaim: true)
        guard commit(cleared) else { return }
        sendContext()
        send(.publication(cleared)) { [weak self] reply in
            if let reply { self?.receive(reply.publication) }
        }
    }

    func receiveContext() {
        guard WCSession.isSupported(),
              let data = WCSession.default.receivedApplicationContext[Self.contextKey] as? Data,
              let publication = try? JSONDecoder().decode(Publication.self, from: data) else { return }
        receive(publication)
    }

    func refreshConnection() {
        receiveContext()
        sendContext()
        connectionGeneration = UUID()
        isConnected = false
        commandPending = false
        commandRejected = false
        requestRemoteWorkout()
    }

    func refreshRemoteWorkout() {
        guard isConnected else { return }
        requestRemoteWorkout()
    }

    private func requestRemoteWorkout() {
        let generation = connectionGeneration
        send(.request) { [weak self] reply in
            guard let self, self.connectionGeneration == generation else { return }
            guard let reply else {
                self.isConnected = false
                return
            }
            self.receive(reply.publication)
            self.isConnected = self.isReachable
        }
    }

    func resetPeer() {
        connectionGeneration = UUID()
        isConnected = false
        commandPending = false
        commandRejected = false
        remote = nil
        retiredSources.removeAll()
    }

    func sendAction(_ action: LiveWorkoutAction, for workoutID: UUID) {
        guard isConnected, !commandPending, let remote, let workout = remote.workout,
              workout.id == workoutID, action.isAvailable(in: workout) else { return }
        let generation = connectionGeneration
        commandPending = true
        commandRejected = false
        send(.command(workoutID, remote.revision, action)) { [weak self] reply in
            guard let self, self.connectionGeneration == generation else { return }
            self.commandPending = false
            if let reply {
                self.receive(reply.publication)
                self.commandRejected = !reply.accepted
            } else {
                self.refreshConnection()
            }
        }
    }

    func reply(to data: Data) -> Data {
        guard let message = try? JSONDecoder().decode(Message.self, from: data) else { return Data() }
        var accepted = true
        var healthMode: WatchWorkoutHealthMode?
        switch message {
        case .publication(let publication):
            receive(publication)
            isConnected = isReachable
        case .claim(let publication):
            receiveContext()
            receive(publication)
            isConnected = isReachable
            if remote?.source == publication.source, remote?.revision == publication.revision {
                healthMode = onWatchClaim?(publication)
            }
            accepted = healthMode != nil
        case .request:
            onClockRefresh?()
        case .command(let id, let revision, let action):
            onClockRefresh?()
            accepted = false
            if let workout = local.workout, workout.id == id, local.revision == revision,
               action.isAvailable(in: workout) {
                onAction?(action)
                accepted = local.revision != revision
            }
        }
        return (try? JSONEncoder().encode(Reply(publication: local, accepted: accepted, healthMode: healthMode))) ?? Data()
    }

    private func receive(_ publication: Publication) {
        guard publication.revision >= 0, publication.workout?.isValid != false,
              !retiredSources.contains(publication.source) else { return }
        if let remote {
            if remote.source == publication.source {
                guard publication.revision > remote.revision else { return }
            } else {
                retiredSources.insert(remote.source)
            }
        }
        remote = publication
        onPeerState?(publication)
    }

    private var isReachable: Bool {
        WCSession.isSupported() && WCSession.default.activationState == .activated && WCSession.default.isReachable
    }

    private func sendContext() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              let data = try? JSONEncoder().encode(local) else { return }
        let session = WCSession.default
        var context = session.applicationContext
        if let previous = context[Self.contextKey] as? Data,
           let publication = try? JSONDecoder().decode(Publication.self, from: previous),
           publication.source == local.source, publication.revision == local.revision { return }
        context[Self.contextKey] = data
        try? session.updateApplicationContext(context)
    }

    private func send(_ message: Message, completion: @escaping @MainActor (Reply?) -> Void) {
        guard isReachable, let data = try? JSONEncoder().encode(message) else {
            completion(nil)
            return
        }
        WCSession.default.sendMessageData(data, replyHandler: { data in
            Task { @MainActor in completion(try? JSONDecoder().decode(Reply.self, from: data)) }
        }, errorHandler: { _ in
            Task { @MainActor in completion(nil) }
        })
    }
}
