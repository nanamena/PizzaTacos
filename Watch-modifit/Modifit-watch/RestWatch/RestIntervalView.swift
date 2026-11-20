import Combine
import SwiftUI

struct RestIntervalView: View {
    let onNext: () -> Void

    @State private var secondsRemaining = 12
    @State private var isOvertime = false

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let cream = Color(red: 1.0, green: 0.94, blue: 0.84)
    private let darkBrown = Color(red: 0.23, green: 0.095, blue: 0.055)
    private let yellow = Color(red: 1.0, green: 0.68, blue: 0.02)
    private let darkText = Color(red: 0.20, green: 0.10, blue: 0.04)

    var body: some View {
        Group {
            if isOvertime {
                RestOvertimeView(onNext: onNext)
                    .transition(.opacity)
            } else {
                restCountdown
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isOvertime)
    }

    private var restCountdown: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                AnimatedMascotView(
                    firstImage: "MascotRestA",
                    secondImage: "MascotRestB",
                    isPaused: false,
                    size: CGSize(width: 170, height: 120)
                )
                    .frame(width: 170, height: 120)
                    .padding(.bottom, 5)

                Text(formattedTime)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(cream)
                    .frame(height: 39)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: secondsRemaining)
                    .accessibilityLabel("Riposo rimanente: \(formattedTime)")

                HStack(spacing: 8) {
                    Button {
                        secondsRemaining += 15
                    } label: {
                        Text("+15 s")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(cream)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(darkBrown, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onNext) {
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
            guard secondsRemaining > 0 else {
                isOvertime = true
                return
            }
            secondsRemaining -= 1
            if secondsRemaining == 0 {
                isOvertime = true
            }
        }
    }

    private var formattedTime: String {
        "\(secondsRemaining / 60):\(String(format: "%02d", secondsRemaining % 60))"
    }
}
