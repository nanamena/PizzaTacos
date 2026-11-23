import SwiftUI

struct FocusWorkoutView: View {
    @Environment(\.appColors) private var appColors

    @ObservedObject var viewModel: FocusWorkoutViewModel
    let historyStore: WorkoutHistoryStore
    let liveLink: LiveWorkoutLink
    let onFinish: () -> Void

    var body: some View {
        Group {
            if viewModel.state == .completed {
                WorkoutCompletionView(viewModel: viewModel, historyStore: historyStore, onFinish: onFinish)
                    .background(appColors.background.ignoresSafeArea())
                    .tint(appColors.primary)
                    .navigationTitle(viewModel.routine.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.visible, for: .navigationBar, .tabBar)
            } else {
                FocusWorkoutSetView(
                    routine: viewModel.routine,
                    workout: viewModel.liveWorkout,
                    showsWatchConflict: liveLink.hasConflict,
                    showsHealthFailure: viewModel.healthSaveStatus == .failed,
                    timing: { _ in (viewModel.remainingWorkoutText, viewModel.workoutDelayText) },
                    onAction: viewModel.applyLiveWorkoutAction
                )
            }
        }
        .sensoryFeedback(.success, trigger: viewModel.completedSets)
    }
}

import SwiftUI

// Esta vista celebra la sesión y registra cómo se sintió la persona al terminar.
struct WorkoutCompletionView: View {
    @Environment(\.appColors) private var appColors

    @ObservedObject var viewModel: FocusWorkoutViewModel
    @StateObject private var feedbackViewModel: WorkoutFeedbackViewModel
    let onFinish: () -> Void

    init(viewModel: FocusWorkoutViewModel, historyStore: WorkoutHistoryStore, onFinish: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onFinish = onFinish
        _feedbackViewModel = StateObject(wrappedValue: WorkoutFeedbackViewModel(historyStore: historyStore, workoutID: viewModel.workoutID))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Text(viewModel.stateTitle)
                    .font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(appColors.text)
                    .multilineTextAlignment(.center)
                Text(viewModel.endedEarly ? "This workout wasn't saved to your history or Apple Health." : "Great work. Every session counts.")
                    .font(.system(size: 15, design: .rounded)).foregroundStyle(appColors.secondaryText)
                    .multilineTextAlignment(.center)

                Image("WorkoutCompletionMascot")
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("ModiFiT mascot celebrating your workout")
                    .frame(width: 190, height: 205).padding(.vertical, 2)

                HStack(spacing: 0) {
                    completionStat("Duration", value: Self.durationText(viewModel.sessionDurationSeconds), symbol: "clock")
                    Rectangle().fill(appColors.border).frame(width: 1, height: 46)
                    completionStat("Exercises", value: "\(viewModel.completedExercises) of \(viewModel.exercises.count)", symbol: "dumbbell.fill")
                }
                .padding(.vertical, 14).appCard()

                if !viewModel.endedEarly && viewModel.healthSaveStatus != .off {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Apple Health", systemImage: "heart.fill")
                            .font(.headline)
                            .foregroundStyle(appColors.text)
                        Text(healthResultText)
                            .font(.subheadline)
                            .foregroundStyle(appColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(15).appCard()
                }

                VStack(alignment: .leading, spacing: 11) {
                    Text(viewModel.endedEarly ? "Workout not completed" : "How did you feel today?")
                        .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(appColors.text)
                    Text("Your feedback helps you understand your training progress.")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(appColors.secondaryText)
                    if !viewModel.endedEarly {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                            ForEach(WorkoutFeeling.allCases) { feeling in feelingChoice(feeling) }
                        }
                    }
                }
                .padding(15).appCard()

                if viewModel.endedEarly {
                    Button {
                        onFinish()
                    } label: {
                        Text("Finish Workout")
                            .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(appColors.surface)
                            .frame(maxWidth: .infinity, minHeight: 56).background(appColors.primary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        feedbackViewModel.save()
                        onFinish()
                    } label: {
                        Text("Save Feedback")
                            .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(appColors.surface)
                            .frame(maxWidth: .infinity, minHeight: 56).background(appColors.primary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(feedbackViewModel.selectedFeeling == nil)
                    .opacity(feedbackViewModel.selectedFeeling == nil ? 0.55 : 1)
                    Button("Skip") { onFinish() }
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(appColors.primary)
                }
            }
            .frame(maxWidth: 600).padding(20).frame(maxWidth: .infinity)
        }
        .background(appColors.background.ignoresSafeArea())
    }

    private func completionStat(_ title: String, value: String, symbol: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 19, weight: .semibold)).foregroundStyle(appColors.primary)
            Text(title).font(.caption).foregroundStyle(appColors.secondaryText)
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(appColors.text)
        }
        .frame(maxWidth: .infinity)
    }

    private var healthResultText: String {
        switch viewModel.healthSaveStatus {
        case .starting, .recording, .saving:
            "Saving workout in Apple Health…"
        case .saved:
            if let energy = viewModel.activeEnergyKilocalories {
                "Active energy: \(energy.formatted(.number.precision(.fractionLength(0)))) kcal · Apple Health"
            } else {
                "Workout saved. Active energy is unavailable."
            }
        case .failed:
            "Workout saved locally, but Apple Health could not save it."
        case .off:
            ""
        }
    }

    private func feelingChoice(_ feeling: WorkoutFeeling) -> some View {
        let selected = feedbackViewModel.selectedFeeling == feeling
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) { feedbackViewModel.selectedFeeling = feeling }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: feeling.symbol).font(.system(size: 17, weight: .semibold))
                Text(feeling.rawValue).font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 14)) }
            }
            .foregroundStyle(selected ? appColors.primary : appColors.text)
            .padding(11).frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? appColors.accent.opacity(0.65) : appColors.background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? appColors.primary : appColors.border, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private static func durationText(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        return hours > 0 ? String(format: "%dh %02dm", hours, minutes) : String(format: "%02d:%02d", minutes, remainder)
    }
}
import SwiftUI

// Esta hoja enumera ejercicios y conserva el control del progreso en la vista activa.
struct WorkoutExerciseListView: View {
    @Environment(\.appColors) private var appColors

    let exercises: [FocusExercise]
    let completedExercises: Int
    let currentIndex: Int

    var body: some View {
        List {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                HStack(spacing: 12) {
                        Image(systemName: index < completedExercises ? "checkmark.circle.fill" : exercise.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(index < completedExercises ? appColors.primary : appColors.secondary)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(appColors.text)
                            Text(exercise.instructionSummary).font(.caption).foregroundStyle(appColors.secondaryText)
                        }
                        Spacer()
                        if index == currentIndex {
                            Text("Current").font(.caption2.bold()).foregroundStyle(appColors.primary)
                        }
                    }
                .padding(.vertical, 5)
                .listRowBackground(appColors.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(appColors.background)
        .navigationTitle("Exercise List")
        .navigationBarTitleDisplayMode(.inline)
        .tint(appColors.primary)
    }
}

// Esta tarjeta resume el tiempo estimado y el progreso.
struct WorkoutStatsView: View {
    @Environment(\.appColors) private var appColors

    let progressLabel: String
    let timing: (Date) -> (remaining: String, delay: String?)

    var body: some View {
        HStack(spacing: 0) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let estimate = timing(context.date)
                stat(symbol: "clock", title: "Time Remaining", value: estimate.remaining, detail: estimate.delay)
            }
            divider
            stat(symbol: "chart.bar.fill", title: "Progress", value: progressLabel)
        }
        .padding(.vertical, 13).appCard()
    }

    private func stat(symbol: String, title: String, value: String, detail: String? = nil) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 21, weight: .semibold)).foregroundStyle(appColors.primary)
            Text(title).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(appColors.secondaryText)
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(appColors.text)
                .lineLimit(1).minimumScaleFactor(0.75)
            if let detail {
                Text(detail).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.red)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle().fill(appColors.border).frame(width: 1, height: 44)
    }
}
import SwiftUI

// Esta tarjeta muestra el ejercicio activo y su progreso por sets.
struct WorkoutSummaryCard: View {
    @Environment(\.appColors) private var appColors

    let exercise: FocusExercise
    let currentSet: Int

    private var setLabel: String { "Set \(currentSet) of \(exercise.sets)" }

    private var exerciseTarget: String {
        if let repetitions = exercise.repetitions { return "\(repetitions) reps" }
        if let duration = exercise.durationSeconds { return "\(duration) sec" }
        return "Exercise"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 13) {
                Image(systemName: exercise.symbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(appColors.primary)
                    .frame(width: 54, height: 54)
                    .background(appColors.accent.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(appColors.text)
                    Text("\(exerciseTarget) · \(setLabel)")
                        .font(.system(size: 14, design: .rounded)).foregroundStyle(appColors.secondaryText)
                }
                Spacer(minLength: 2)
            }
            HStack(spacing: 5) {
                ForEach(0..<max(exercise.sets, 0), id: \.self) { index in
                    Capsule()
                        .fill(index < currentSet ? appColors.primary : appColors.accent.opacity(0.65))
                        .frame(height: 7)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(setLabel)
        }
        .padding(15).appCard()
    }
}
import SwiftUI

struct WorkoutTimerView: View {
    @Environment(\.appColors) private var appColors
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize: CGFloat = 48
    let workout: LiveWorkoutSnapshot?

    var body: some View {
        VStack(spacing: 10) {
            WorkoutAnimatedMascot(workout: workout)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 260)

            if let workout {
                if workout.resting || workout.pausedAt != nil || workout.deadline != nil {
                    Text(phaseTitle(for: workout))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(appColors.secondaryText)
                }
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let timer = workout.timerText(at: context.date)
                    Text(timer)
                        .font(.system(size: timerFontSize, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(restOvertimeStart(at: context.date) == nil ? appColors.text : .red)
                        .lineLimit(1).minimumScaleFactor(0.5).frame(minHeight: 41)
                        .accessibilityLabel(workout.resting ? "Rest timer" : "Set timer")
                        .accessibilityValue(timer)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func phaseTitle(for workout: LiveWorkoutSnapshot) -> LocalizedStringKey {
        if workout.pausedAt != nil { return workout.resting ? "Rest · Paused" : "Paused" }
        return workout.resting ? "Rest" : "Exercise"
    }

    private func restOvertimeStart(at date: Date) -> Date? {
        guard let workout, workout.resting, let deadline = workout.deadline,
              deadline <= (workout.pausedAt ?? date) else { return nil }
        return deadline
    }

}
import SwiftUI

// Este componente usa la mascota oficial disponible sin recortar ni cambiar sus proporciones.
struct MascotWorkoutView: View {
    let accessibilityDescription: String

    var body: some View {
        Image("ModiFiTMascot")
            .resizable()
            .scaledToFit()
            .accessibilityLabel(accessibilityDescription)
    }
}
import SwiftUI

// Este componente da tamaño accesible a los controles circulares del entrenamiento.
struct WorkoutActionButton: View {
    @Environment(\.appColors) private var appColors

    let symbol: String
    let label: String
    var isEmphasized = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(isEmphasized ? appColors.primary : appColors.secondary)
                .frame(width: 58, height: 58)
                .background(appColors.accent.opacity(0.5), in: Circle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(label)
    }
}

// Este botón ancho marca acciones importantes en la sesión.
struct WorkoutPrimaryAction: View {
    @Environment(\.appColors) private var appColors

    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(appColors.surface)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(appColors.primary, in: Capsule())
                .overlay(Capsule().stroke(appColors.secondary, lineWidth: 1))
                .shadow(color: appColors.secondary.opacity(0.14), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(SoftPressStyle())
    }
}
