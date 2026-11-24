import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WorkoutLiveActivityLiveActivity: Widget {
    @Environment(\.colorScheme) private var colorScheme

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreenCard(context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    islandMascot
                }
            } compactLeading: {
                islandMascot
            } compactTrailing: {
                EmptyView()
            } minimal: {
                islandMascot
            }
            .keylineTint(keylineColor(context.state))
        }
    }

    private func lockScreenCard(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                mascot
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.routineName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if context.state.isResting && context.state.setNumber == 1 {
                        Text("Up Next")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(context.state.exerciseName)
                        .font(.headline)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(phaseTitle(context.state))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    timerText(context.state)
                        .font(.title2.weight(.semibold).monospacedDigit())
                }
            }

            lockScreenFooter(context)
        }
        .padding(14)
    }

    private func lockScreenFooter(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        let setCount = Text("Set \(context.state.setNumber) of \(context.state.setsInExercise)")
            .font(.caption)
            .foregroundStyle(.secondary)
        let action = lockScreenAction(context)

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                setCount.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                action.fixedSize(horizontal: true, vertical: false)
            }

            VStack(alignment: .leading, spacing: 4) {
                setCount
                action.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private func lockScreenAction(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        if context.state.canAdvance {
            advanceButton(context)
        } else {
            connectionStatus(context)
        }
    }

    private var mascot: some View {
        Image("ModiFiTMascot")
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
    }

    private var islandMascot: some View {
        Image("ModiFiTMascot")
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func timerText(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        if let deadline = state.deadline {
            Text(timerInterval: state.timerStartAt...deadline, pauseTime: state.pausedAt, countsDown: true)
                .monospacedDigit()
        } else if let pausedAt = state.pausedAt {
            Text(timerInterval: state.timerStartAt...pausedAt, pauseTime: pausedAt, countsDown: false)
                .monospacedDigit()
        } else {
            Text(state.timerStartAt, style: .timer)
                .monospacedDigit()
        }
    }

    private func phaseTitle(_ state: WorkoutActivityAttributes.ContentState) -> String {
        if state.pausedAt != nil { return "Paused" }
        return state.isResting ? "Rest" : "Workout"
    }

    private func actionTitle(_ state: WorkoutActivityAttributes.ContentState) -> String {
        if !state.isResting { return "Finish Set" }
        return state.setNumber == 1 ? "Next Exercise" : "Next Set"
    }

    private func advanceButton(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        Button(intent: AdvanceWorkoutIntent(
            workoutID: context.attributes.workoutID,
            sourceID: context.attributes.sourceID,
            revision: context.state.revision
        )) {
            Label(actionTitle(context.state), systemImage: "forward.end.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(minHeight: 36)
                .background(buttonColor(context.state), in: Capsule())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func buttonColor(_ state: WorkoutActivityAttributes.ContentState) -> Color {
        let hex = colorScheme == .dark ? state.darkButtonColor : state.lightButtonColor
        return color(from: hex)
    }

    private func keylineColor(_ state: WorkoutActivityAttributes.ContentState) -> Color {
        let hex = colorScheme == .dark ? state.darkKeylineColor : state.lightKeylineColor
        return color(from: hex)
    }

    private func color(from hex: UInt32) -> Color {
        return Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    @ViewBuilder
    private func connectionStatus(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        if context.state.pausedAt != nil {
            Text("Paused")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if context.attributes.isWatchWorkout {
            Text("Waiting for Apple Watch")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
