import SwiftUI

struct WatchWorkoutSummaryView: View {
    let result: WatchWorkoutResult
    let activeEnergy: Double?
    let onDone: () -> Void

    @Environment(\.appColors) private var colors
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var duration: Duration {
        .seconds(result.record.durationSeconds)
    }

    private var durationPattern: Duration.TimeFormatStyle.Pattern {
        result.record.durationSeconds >= 3_600 ? .hourMinuteSecond : .minuteSecond
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                VStack(spacing: 2) {
                    Text("Workout Complete")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text(result.record.routineName)
                        .font(.subheadline)
                        .foregroundStyle(colors.secondaryText)
                }

                Text(duration, format: .time(pattern: durationPattern))
                    .font(.system(.title, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 0 : -4)
                    .accessibilityLabel("Duration")
                    .accessibilityValue(Text(duration, format: .units(allowed: [.hours, .minutes, .seconds], width: .wide)))

                if let activeEnergy {
                    Text("\(activeEnergy.formatted(.number.precision(.fractionLength(0)))) kcal active energy")
                        .font(.footnote)
                        .foregroundStyle(colors.secondaryText)
                }

                if result.health == .failed {
                    Text("Saved on Apple Watch. Couldn’t save to Apple Health.")
                        .font(.footnote)
                        .foregroundStyle(colors.secondaryText)
                }
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(colors.text)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Done", action: onDone)
                .buttonStyle(WatchActionStyle())
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .background(.black)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
