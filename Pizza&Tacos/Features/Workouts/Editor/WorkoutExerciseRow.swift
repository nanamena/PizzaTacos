import SwiftUI

struct WorkoutExerciseRow: View {
    let exercise: WorkoutExercise

    private var symbol: String {
        if exercise.sourceSymbol != "dumbbell.fill" { return exercise.sourceSymbol }

        let gymSymbols = [
            "dumbbell.fill",
            "figure.strengthtraining.traditional",
            "figure.core.training",
            "figure.indoor.cycle",
            "figure.rower"
        ]
        let stableIndex = exercise.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) } % gymSymbols.count
        return gymSymbols[stableIndex]
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3).foregroundStyle(.tint)
                .frame(width: 40).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name).font(.headline).foregroundStyle(.primary)
                Text(exercise.isTimed
                     ? "\(exercise.sets) sets · \(exercise.duration ?? 0)s · \(exercise.rest)s rest"
                     : "\(exercise.sets) sets · \(exercise.reps) reps · \(exercise.rest)s rest")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.footnote.bold())
                .foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .frame(minHeight: 52)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit exercise")
    }
}
