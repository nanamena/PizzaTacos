import SwiftUI

struct WorkoutDurationPicker: View {
    @Environment(\.locale) private var locale
    let title: LocalizedStringResource
    @Binding var value: Int
    let range: ClosedRange<Int>

    private var selectedValue: Int {
        min(range.upperBound, max(range.lowerBound, value))
    }

    private var minuteRange: ClosedRange<Int> {
        (range.lowerBound / 60)...(range.upperBound / 60)
    }

    private var secondRange: ClosedRange<Int> {
        let minuteStart = selectedValue / 60 * 60
        return max(0, range.lowerBound - minuteStart)...min(59, range.upperBound - minuteStart)
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { selectedValue / 60 },
            set: { minute in
                let seconds = minute * 60 + selectedValue % 60
                value = min(range.upperBound, max(range.lowerBound, seconds))
            }
        )
    }

    private var seconds: Binding<Int> {
        Binding(
            get: { selectedValue % 60 },
            set: { value = selectedValue / 60 * 60 + $0 }
        )
    }

    private var formattedValue: Text {
        if value == 0 {
            return Text("No Rest")
        }

        let duration = Duration.seconds(value)
        return Text(duration.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated).locale(locale)))
            .accessibilityLabel(Text(duration.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(locale))))
    }

    var body: some View {
        DisclosureGroup {
            Picker("Minutes", selection: minutes) {
                ForEach(minuteRange, id: \.self) { minute in
                    Text(minute, format: .number).tag(minute)
                }
            }
            .pickerStyle(.menu)

            Picker("Seconds", selection: seconds) {
                ForEach(secondRange, id: \.self) { second in
                    Text(second, format: .number).tag(second)
                }
            }
            .pickerStyle(.menu)
            .disabled(secondRange.lowerBound == secondRange.upperBound)
        } label: {
            LabeledContent {
                formattedValue.monospacedDigit()
            } label: {
                Text(title)
            }
            .frame(minHeight: 44)
        }
    }
}
