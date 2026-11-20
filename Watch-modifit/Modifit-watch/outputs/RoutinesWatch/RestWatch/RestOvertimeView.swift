import Combine
import SwiftUI

struct RestOvertimeView: View {
    let onNext: () -> Void

    @State private var overtimeSeconds = 0

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let cream = Color(red: 1.0, green: 0.94, blue: 0.84)
    private let yellow = Color(red: 1.0, green: 0.68, blue: 0.02)
    private let coral = Color(red: 1.0, green: 0.39, blue: 0.40)
    private let darkText = Color(red: 0.20, green: 0.10, blue: 0.04)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Image("MascotOvertimeA")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 170, height: 170)
                        .opacity(currentMascotAsset == "MascotOvertimeA" ? 1 : 0)

                    Image("MascotOvertimeB")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 170, height: 170)
                        .opacity(currentMascotAsset == "MascotOvertimeB" ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.30), value: currentMascotAsset)
                .accessibilityHidden(true)

                Text("+\(formattedTime)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(coral)
                    .frame(height: 36)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: overtimeSeconds)
                    .accessibilityLabel("Riposo superato di \(formattedTime)")

                Button(action: onNext) {
                    Text("Next")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(darkText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(yellow, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }
            .padding(.horizontal, 12)
            .padding(.top, 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(clock) { _ in
            overtimeSeconds += 1
        }
    }

    private var currentMascotAsset: String {
        overtimeSeconds < 20 ? "MascotOvertimeA" : "MascotOvertimeB"
    }

    private var formattedTime: String {
        "\(overtimeSeconds / 60):\(String(format: "%02d", overtimeSeconds % 60))"
    }
}
