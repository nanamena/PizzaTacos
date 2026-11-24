import SwiftUI

struct WatchActiveWorkoutView: View {
    let workout: LiveWorkoutSnapshot
    let actionsEnabled: Bool
    var isConnected = true
    var hasConflict = false
    var healthFailed = false
    var commandRejected = false
    var onBrowseRoutines: (() -> Void)?
    let onAction: (LiveWorkoutAction) -> Void

    @Environment(\.appColors) private var colors
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 34
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var page: Page = .timer
    @State private var confirmsDiscard = false

    private enum Page: Hashable {
        case controls, timer, details
    }

    var body: some View {
        TabView(selection: $page) {
            controlsPage.tag(Page.controls)
            timerPage.tag(Page.timer)
            detailsPage.tag(Page.details)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .foregroundStyle(colors.text)
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("End this workout?", isPresented: $confirmsDiscard) {
            Button("Discard Workout", role: .destructive) { perform(.discard) }
                .disabled(!actionsEnabled)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress in this workout will be discarded.")
        }
    }

    private var timerPage: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            ViewThatFits(in: .vertical) {
                WatchTimerLayout {
                    timerHeader
                    timerMascot
                    timerFooter(at: context.date)
                }
                ScrollView {
                    VStack(spacing: 4) {
                        timerHeader
                        timerMascot.frame(height: 72)
                        timerFooter(at: context.date)
                    }
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Reclaim some of the page margins between the system clock and the page dots.
            .padding(.top, -20)
            .padding(.bottom, -20)
        }
    }

    private var timerHeader: some View {
        VStack(spacing: 4) {
            if workout.pausedAt != nil {
                Text("Paused").font(.footnote)
            }
            timerStatus
        }
    }

    private func timerFooter(at date: Date) -> some View {
        VStack(spacing: 2) {
            timerText(at: date, size: timerSize)
                .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 0 : -4)
            nextButton
        }
    }

    private func isOvertime(at date: Date) -> Bool {
        workout.resting && (workout.deadline.map { $0 <= (workout.pausedAt ?? date) } ?? false)
    }

    private var timerMascot: some View {
        WorkoutAnimatedMascot(workout: workout, isVisible: page == .timer)
            .frame(maxWidth: 166)
    }

    @ViewBuilder
    private var timerStatus: some View {
        if !isConnected {
            Text("Connection lost").font(.footnote)
        } else if commandRejected {
            Text("Couldn’t apply that action. Try again.").font(.footnote)
        }
    }

    private func timerText(at date: Date, size: CGFloat) -> some View {
        let timer = workout.timerText(at: date)
        return Text(timer)
            .font(.system(size: size, weight: .bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .foregroundStyle(isOvertime(at: date) ? Color.red : colors.text)
            .accessibilityLabel(workout.resting ? "Rest timer" : "Set timer")
            .accessibilityValue(timer)
            .accessibilityAction(named: Text("Workout Controls")) { page = .controls }
            .accessibilityAction(named: Text("Exercise Details")) { page = .details }
    }

    private var nextButton: some View {
        Button("Next") { perform(workout.resting ? .skipRest : .finishSet) }
            .buttonStyle(WatchActionStyle())
            .disabled(!actionsEnabled || workout.pausedAt != nil)
    }

    private var controlsPage: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Controls")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityAction(named: Text("Timer")) { page = .timer }

                if !isConnected {
                    Text("Connection lost")
                        .font(.footnote)
                        .foregroundStyle(colors.secondaryText)
                } else if commandRejected {
                    Text("Couldn’t apply that action. Try again.")
                        .font(.footnote)
                }

                if hasConflict {
                    Label("A separate workout is running on iPhone.", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                }
                if healthFailed {
                    Text("Apple Health recording unavailable")
                        .font(.footnote)
                }

                if workout.pausedAt != nil {
                    Button("Resume") { perform(.resume) }
                        .buttonStyle(WatchActionStyle())
                        .disabled(!actionsEnabled)
                } else {
                    Button("Pause") { perform(.pause) }
                        .buttonStyle(WatchActionStyle(kind: .secondary))
                        .disabled(!actionsEnabled)
                }

                Button("End Workout", role: .destructive) { confirmsDiscard = true }
                    .buttonStyle(WatchActionStyle(kind: .destructive))
                    .disabled(!actionsEnabled)

                if !isConnected, let onBrowseRoutines {
                    Button("Browse Routines", action: onBrowseRoutines)
                        .buttonStyle(WatchActionStyle(kind: .secondary))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }

    private var detailsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if workout.resting {
                    Text("Up Next")
                        .font(.footnote)
                        .foregroundStyle(colors.secondaryText)
                }

                Text(workout.exercise.name)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityAction(named: Text("Timer")) { page = .timer }
                Text("Set \(workout.position.set) of \(workout.exercise.sets)")
                    .foregroundStyle(colors.secondaryText)
                if let duration = workout.exercise.durationSeconds {
                    Text(Duration.seconds(duration), format: .units())
                } else if let repetitions = workout.exercise.repetitions {
                    Text("\(repetitions) reps")
                }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private func perform(_ action: LiveWorkoutAction) {
        guard actionsEnabled, action.isAvailable(in: workout) else { return }
        onAction(action)
    }
}
