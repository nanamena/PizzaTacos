import SwiftUI

struct WatchRoutineRow: View {
    let routine: Routine

    @Environment(\.appColors) private var colors
    @ScaledMetric(relativeTo: .body) private var symbolColumnWidth: CGFloat = 28

    var body: some View {
        HStack(alignment: .center) {
            Image(systemName: routine.symbol)
                .font(.body)
                .foregroundStyle(colors.primary)
                .frame(width: symbolColumnWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(routine.name)
                    .font(.system(.headline))
                    .foregroundStyle(.primary)
                ViewThatFits(in: .horizontal) {
                    Text("\(exerciseCount) · \(estimatedTime)")
                        .fixedSize(horizontal: true, vertical: false)

                    VStack(alignment: .leading, spacing: 0) {
                        exerciseCount
                        estimatedTime
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var exerciseCount: Text {
        if routine.exerciseCount == 1 {
            Text("1 exercise")
        } else {
            Text("\(routine.exerciseCount) exercises")
        }
    }

    private var estimatedTime: Text {
        Text("~\(routine.estimatedMinutes) min")
    }
}
