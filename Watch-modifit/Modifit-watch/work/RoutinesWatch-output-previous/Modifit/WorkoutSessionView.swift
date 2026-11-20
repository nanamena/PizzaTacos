import Combine
import SwiftUI

struct WorkoutSessionView: View {
    let routine: WorkoutRoutine

    @State private var elapsedSeconds = 20
    @State private var isPaused = false
    @State private var exerciseIndex = 1
    @State private var isResting = false

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let cream = Color(red: 1.0, green: 0.94, blue: 0.84)
    private let darkBrown = Color(red: 0.23, green: 0.095, blue: 0.055)
    private let yellow = Color(red: 1.0, green: 0.68, blue: 0.02)
    private let darkText = Color(red: 0.20, green: 0.10, blue: 0.04)

    var body: some View {
        Group {
            if isResting {
                RestIntervalView {
                    elapsedSeconds = 0
                    isPaused = false
                    isResting = false
                }
            } else {
                activeWorkout
            }
        }
    }

    private var activeWorkout: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                animatedMascot
                    .frame(width: 170, height: 120)
                    .padding(.bottom, 5)

                Text(formattedTime)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(cream)
                    .frame(height: 39)
                    .accessibilityLabel("Tempo trascorso: \(formattedTime)")

                HStack(spacing: 8) {
                    Button {
                        isPaused.toggle()
                    } label: {
                        Text(isPaused ? "Resume" : "Pause")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(cream)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(darkBrown, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: advanceToNextExercise) {
                        Text("Next")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(darkText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(yellow, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 12)
            .padding(.top, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(clock) { _ in
            guard !isPaused else { return }
            elapsedSeconds += 1
        }
    }

    private var animatedMascot: some View {
        TimelineView(.animation(minimumInterval: 0.30, paused: isPaused)) { context in
            let frameIndex = Int(context.date.timeIntervalSinceReferenceDate / 0.30) % 2
            let imageName = frameIndex == 0 ? "MascotBikeA" : "MascotBikeB"

            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 170, height: 120)
                .animation(.easeInOut(duration: 0.12), value: imageName)
                .accessibilityHidden(true)
        }
    }

    private var formattedTime: String {
        "\(elapsedSeconds / 60):\(String(format: "%02d", elapsedSeconds % 60))"
    }

    private func advanceToNextExercise() {
        exerciseIndex = exerciseIndex % max(routine.exerciseCount, 1) + 1
        isPaused = false
        isResting = true
    }
}
