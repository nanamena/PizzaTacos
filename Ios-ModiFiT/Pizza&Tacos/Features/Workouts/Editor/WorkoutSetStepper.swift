import SwiftUI

struct WorkoutSetStepper: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledButtonSize = 28.0
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        let buttonSize = max(44, scaledButtonSize)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            LabeledContent {
                Text(value, format: .number)
                    .monospacedDigit()
            } label: {
                Text("Sets")
            }
            .accessibilityHidden(true)

            HStack(spacing: 0) {
                Button(action: decrement) {
                    Label("Decrease sets", systemImage: "minus")
                        .frame(width: buttonSize, height: buttonSize)
                        .contentShape(.rect)
                }
                .disabled(value <= range.lowerBound)
                .accessibilityValue(Text(value, format: .number))

                Divider()
                    .frame(height: buttonSize / 2)
                    .accessibilityHidden(true)

                Button(action: increment) {
                    Label("Increase sets", systemImage: "plus")
                        .frame(width: buttonSize, height: buttonSize)
                        .contentShape(.rect)
                }
                .disabled(value >= range.upperBound)
                .accessibilityValue(Text(value, format: .number))
            }
            .labelStyle(.iconOnly)
            .font(.body.weight(.semibold))
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .frame(minHeight: 44)
    }

    private func decrement() {
        guard value > range.lowerBound else { return }
        value = min(range.upperBound, value - 1)
    }

    private func increment() {
        guard value < range.upperBound else { return }
        value = max(range.lowerBound, value + 1)
    }
}
