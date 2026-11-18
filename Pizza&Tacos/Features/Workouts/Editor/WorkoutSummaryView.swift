import SwiftUI

struct WorkoutSummaryView: View {
    let exercises: [WorkoutExercise]

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Estimated Time")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            Text("\(estimatedMinutes) min")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private var estimatedMinutes: Int {
        WorkoutTiming.totalMinutes(for: exercises.map { $0.makeFocusExercise() })
    }
}
