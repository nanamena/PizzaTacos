import SwiftUI

struct StartScreenView: View {
    let onStart: () -> Void

    private let buttonTop = Color(red: 1.0, green: 0.75, blue: 0.12)
    private let buttonBottom = Color(red: 1.0, green: 0.65, blue: 0.02)
    private let buttonText = Color(red: 0.20, green: 0.10, blue: 0.04)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170, height: 170)
                    .accessibilityHidden(true)

                Button(action: onStart) {
                    Text("Start")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(buttonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(
                                colors: [buttonTop, buttonBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 14)
            .padding(.top, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.black)
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .toolbar(.hidden, for: .navigationBar)
    }
}
