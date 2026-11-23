import SwiftUI

struct WatchAnimatedMascot: View {
    enum Phase: Equatable {
        case exercising, resting, overtime

        var frames: (String, String) {
            switch self {
            case .exercising: ("WorkoutAnimationCycle1", "WorkoutAnimationCycle2")
            case .resting: ("WorkoutAnimationRest1", "WorkoutAnimationRest2")
            case .overtime: ("WorkoutAnimationMelt1", "WorkoutAnimationMelt2")
            }
        }
    }

    let phase: Phase
    let pausedAt: Date?
    var overtimeStartedAt: Date?
    var presentationDate: Date = .now
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        let animate = !reduceMotion && scenePhase == .active && !isLuminanceReduced
        let overtimeFinished = overtimeStartedAt.map { presentationDate.timeIntervalSince($0) >= 20.30 } ?? false
        let schedulePaused = !animate || pausedAt != nil || overtimeFinished
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: schedulePaused)) { context in
            let date = pausedAt ?? (schedulePaused ? presentationDate : context.date)
            let frames = phase.frames
            let blend = blend(at: date, animate: animate)
            ZStack {
                mascot(frames.0).opacity(1 - blend)
                mascot(frames.1).opacity(blend)
            }
            .frame(maxWidth: 170, maxHeight: height)
        }
        .accessibilityHidden(true)
    }

    private func mascot(_ name: String) -> some View {
        Image(decorative: name)
            .resizable()
            .scaledToFit()
    }

    private func blend(at date: Date, animate: Bool) -> Double {
        if let overtimeStartedAt, phase == .overtime {
            let elapsed = date.timeIntervalSince(overtimeStartedAt) - 20
            return animate ? smoothStep(elapsed / 0.30) : (elapsed >= 0 ? 1 : 0)
        }
        guard animate else { return 0 }
        let cycle = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.60)
        let firstPose = cycle < 0.30
        let progress = smoothStep(((firstPose ? cycle : cycle - 0.30) - 0.12) / 0.18)
        return firstPose ? progress : 1 - progress
    }

    private func smoothStep(_ progress: Double) -> Double {
        let value = min(max(progress, 0), 1)
        return value * value * (3 - 2 * value)
    }
}
