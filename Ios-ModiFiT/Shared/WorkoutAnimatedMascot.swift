import SwiftUI

struct WorkoutAnimatedMascot: View {
    let workout: LiveWorkoutSnapshot?
    var isVisible = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    #if os(watchOS)
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    #endif

    private var animates: Bool {
        guard isVisible, scenePhase == .active, !reduceMotion, let workout, workout.pausedAt == nil else { return false }
        #if os(watchOS)
        return !isLuminanceReduced
        #else
        return true
        #endif
    }

    var body: some View {
        let start = workout.flatMap { $0.resting ? $0.deadline : $0.setStartedAt } ?? .now
        Color.clear.overlay {
            if animates {
                TimelineView(.periodic(from: start.addingTimeInterval(-ceil(max(0, start.timeIntervalSinceNow))), by: 0.2)) { context in
                    pose(at: context.date)
                }
            } else {
                pose(at: .now)
            }
        }
        .accessibilityHidden(true)
    }

    private func pose(at date: Date) -> some View {
        let imageName = WorkoutMascotPose.imageName(for: workout, at: date, reduceMotion: reduceMotion)
        let image = Image(decorative: imageName)
            .resizable()
            .scaledToFit()
        #if os(watchOS)
        // Compensate for the extra transparent space in the two rest frames.
        return image.scaleEffect(imageName.hasPrefix("WorkoutAnimationRest") ? 1.25 : 1)
        #else
        return image
        #endif
    }
}
