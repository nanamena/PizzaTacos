import SwiftUI

struct WatchActiveWorkoutView: View {
    let active: WatchWorkoutState
    let model: WatchWorkoutModel
    let confirmDiscard: () -> Void

    @Environment(\.appColors) private var colors
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var mascotHeight: CGFloat { dynamicTypeSize.isAccessibilitySize ? 72 : 96 }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if let deadline = active.deadline {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = deadline.timeIntervalSince(active.pausedAt ?? context.date)
                        let inOvertime = active.resting && remaining <= 0
                        let seconds = Int(inOvertime ? -remaining : max(0, ceil(remaining)))
                        let duration = Duration.seconds(seconds)

                        WatchAnimatedMascot(
                            phase: inOvertime ? .overtime : active.resting ? .resting : .exercising,
                            pausedAt: active.pausedAt,
                            overtimeStartedAt: inOvertime ? deadline : nil,
                            presentationDate: context.date,
                            height: mascotHeight
                        )

                        Group {
                            if inOvertime {
                                Text("+\(duration, format: .time(pattern: .minuteSecond))")
                                    .foregroundStyle(Color(red: 1, green: 0.39, blue: 0.40))
                                    .accessibilityLabel("Rest overtime")
                            } else {
                                Text(duration, format: .time(pattern: .minuteSecond))
                                    .accessibilityLabel(active.resting ? "Rest time remaining" : "Time remaining")
                            }
                        }
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .accessibilityValue(Text(duration, format: .units()))
                    }
                } else {
                    WatchAnimatedMascot(phase: .exercising, pausedAt: active.pausedAt, height: mascotHeight)
                    if let repetitions = active.exercise.repetitions {
                        Text("\(repetitions) reps")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    }
                }

                controls

                if active.pausedAt != nil {
                    Text("Paused").font(.headline)
                } else if active.resting {
                    Text("Rest").font(.headline)
                }
                Text(active.resting ? "Next: \(active.exercise.name)" : active.exercise.name)
                    .font(.headline)
                Text("Set \(active.position.set) of \(active.exercise.sets)")
                    .font(.footnote)
                    .foregroundStyle(colors.secondaryText)

                if active.health == .failed {
                    Text("Apple Health recording unavailable").font(.footnote)
                }
                Button("End Workout", role: .destructive, action: confirmDiscard)
                    .buttonStyle(WatchActionStyle(kind: .destructive))
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(colors.text)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .disabled(model.busy)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var controls: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            if active.pausedAt != nil {
                Button("Resume", action: model.togglePause)
                    .buttonStyle(WatchActionStyle())
            } else {
                Button("Pause", action: model.togglePause)
                    .buttonStyle(WatchActionStyle(kind: .secondary))
                if active.resting {
                    Button("Next Set", action: model.nextSet)
                        .buttonStyle(WatchActionStyle())
                } else if active.deadline == nil {
                    Button("Complete Set", action: model.finishSet)
                        .buttonStyle(WatchActionStyle())
                }
            }
        }
    }
}
