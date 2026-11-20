import SwiftUI

struct ExerciseNumberField: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: LocalizedStringResource
    @Binding var value: Int
    let range: ClosedRange<Int>

    private var options: [Int] {
        if range.contains(value) { return Array(range) }
        return (Array(range) + [value]).sorted()
    }

    private var picker: some View {
        Picker(title, selection: $value) {
            ForEach(options, id: \.self) { option in
                Text(option, format: .number).tag(option)
            }
        }
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            DisclosureGroup {
                picker
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(title))
                    .accessibilityValue(Text(value, format: .number))
                    .accessibilityAdjustableAction(adjustValue)
            } label: {
                LabeledContent {
                    Text(value, format: .number)
                        .monospacedDigit()
                } label: {
                    Text(title)
                }
                .frame(minHeight: 44)
            }
        }
    }

    private func adjustValue(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment where value < range.upperBound:
            value = max(range.lowerBound, value + 1)
        case .decrement where value > range.lowerBound:
            value = min(range.upperBound, value - 1)
        default:
            break
        }
    }
}
