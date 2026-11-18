import SwiftUI

struct WorkoutMascotHeader: View {
    let mascot: Image?
    let isEmpty: Bool
    var body: some View {
        VStack(spacing: 12) {
            if let mascot {
                mascot.resizable().scaledToFit()
                    .frame(maxHeight: isEmpty ? 150 : 90)
                    .accessibilityHidden(true)
            }
            Text("Make it your workout.").font(.title2).bold()
            Text("Add your exercises and we'll estimate the time for you.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .padding(.horizontal)
    }
}
