import SwiftUI

struct AnimatedMascotView: View {
    let firstImage: String
    let secondImage: String
    let isPaused: Bool
    let size: CGSize

    private let frameDuration = 0.30
    private let holdDuration = 0.12

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isPaused)) { context in
            let animationTime = context.date.timeIntervalSinceReferenceDate
            let step = Int(floor(animationTime / frameDuration))
            let elapsed = animationTime.truncatingRemainder(dividingBy: frameDuration)
            let fadeProgress = min(max((elapsed - holdDuration) / (frameDuration - holdDuration), 0), 1)
            let poseBlend = smoothStep(fadeProgress)
            let secondImageOpacity = step.isMultiple(of: 2) ? poseBlend : 1 - poseBlend

            ZStack {
                mascot(firstImage)
                    .opacity(1 - secondImageOpacity)

                mascot(secondImage)
                    .opacity(secondImageOpacity)
            }
            .frame(width: size.width, height: size.height)
            .compositingGroup()
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private func mascot(_ imageName: String) -> some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
    }

    private func smoothStep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}
