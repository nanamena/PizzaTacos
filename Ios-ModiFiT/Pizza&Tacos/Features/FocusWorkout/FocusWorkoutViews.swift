import SwiftUI

// Esta vista presenta el entrenamiento activo y conecta sus controles con el ViewModel.
struct FocusWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FocusWorkoutViewModel
    private let historyStore: WorkoutHistoryStore
    private let onWorkoutCompleted: () -> Void

    init(routine: Routine, historyStore: WorkoutHistoryStore, onWorkoutCompleted: @escaping () -> Void = {}) {
        self.historyStore = historyStore
        self.onWorkoutCompleted = onWorkoutCompleted
        _viewModel = StateObject(wrappedValue: FocusWorkoutViewModel(routine: routine, historyStore: historyStore))
    }

    var body: some View {
        Group {
            if viewModel.state == .completed {
                WorkoutCompletionView(viewModel: viewModel, historyStore: historyStore, onFinish: dismiss.callAsFunction)
            } else {
                activeWorkoutScreen
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.primary)
        .navigationTitle(viewModel.routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar, .tabBar)
        .toolbar {
            if viewModel.state != .completed {
                ToolbarItem(placement: .topBarLeading) {
                    Button { viewModel.showingEndConfirmation = true } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(AppColors.primary)
                    }
                    .accessibilityLabel("End workout")
                    .confirmationDialog("End this workout?", isPresented: $viewModel.showingEndConfirmation, titleVisibility: .visible) {
                        Button("Keep Workout Running", role: .cancel) { }
                        Button("End Workout", role: .destructive) { viewModel.endWorkout() }
                    } message: {
                        Text("Your completed sets will be included in this session.")
                    }
                }
            }
        }
        .onAppear { viewModel.startWorkout() }
        .onChange(of: viewModel.state) { _, state in
            if state == .completed && !viewModel.endedEarly {
                onWorkoutCompleted()
            }
        }
        .sheet(item: $viewModel.presentedSheet) { route in
            NavigationStack {
                switch route {
                case .exerciseList:
                    WorkoutExerciseListView(exercises: viewModel.exercises,
                                            completedExercises: viewModel.completedExercises,
                                            currentIndex: viewModel.exerciseIndex)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(.success, trigger: viewModel.completedSets)
    }

    private var activeWorkoutScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 15) {
                WorkoutSummaryCard(viewModel: viewModel)
                WorkoutTimerView(viewModel: viewModel)

                WorkoutStatsView(viewModel: viewModel)
            }
            .frame(maxWidth: 600).padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 18)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionControls
                .frame(maxWidth: 600)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(AppColors.background)
        }
    }

    // Este grupo muestra controles relevantes según la fase del ejercicio.
    @ViewBuilder
    private var actionControls: some View {
        if viewModel.state == .resting {
            HStack(spacing: 11) {
                WorkoutPrimaryAction(title: viewModel.restLeadsToNextExercise ? "Next Exercise" : "Next Set", symbol: "forward.end.fill", action: viewModel.skipRest)
                WorkoutActionButton(symbol: "list.bullet", label: "Exercise List", action: viewModel.showExerciseList)
            }
        } else {
            HStack(spacing: 12) {
                WorkoutPrimaryAction(title: "Finish Set", symbol: "checkmark", action: viewModel.finishCurrentSet)
                WorkoutActionButton(symbol: "list.bullet", label: "Exercise List", action: viewModel.showExerciseList)
            }
        }
    }
}
import SwiftUI

// Esta vista celebra la sesión y registra cómo se sintió la persona al terminar.
struct WorkoutCompletionView: View {
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
                    .font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                    .multilineTextAlignment(.center)
                Text(viewModel.endedEarly ? "Your workout progress has been saved for this session." : "Great work. Every session counts.")
                    .font(.system(size: 15, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                    .multilineTextAlignment(.center)

                Image("WorkoutCompletionMascot")
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("ModiFiT mascot celebrating your workout")
                    .frame(width: 190, height: 205).padding(.vertical, 2)

                HStack(spacing: 0) {
                    completionStat("Duration", value: Self.durationText(viewModel.sessionDurationSeconds), symbol: "clock")
                    Rectangle().fill(AppColors.border).frame(width: 1, height: 46)
                    completionStat("Exercises", value: "\(viewModel.completedExercises) of \(viewModel.exercises.count)", symbol: "dumbbell.fill")
                }
                .padding(.vertical, 14).appCard()

                VStack(alignment: .leading, spacing: 11) {
                    Text(viewModel.endedEarly ? "Workout not completed" : "How did you feel today?")
                        .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                    Text("Your feedback helps you understand your training progress.")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(AppColors.secondaryText)
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
                            .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(AppColors.surface)
                            .frame(maxWidth: .infinity, minHeight: 56).background(AppColors.primary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        feedbackViewModel.save()
                        onFinish()
                    } label: {
                        Text("Save Feedback")
                            .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(AppColors.surface)
                            .frame(maxWidth: .infinity, minHeight: 56).background(AppColors.primary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(feedbackViewModel.selectedFeeling == nil)
                    .opacity(feedbackViewModel.selectedFeeling == nil ? 0.55 : 1)
                    Button("Skip") { onFinish() }
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(AppColors.primary)
                }
            }
            .frame(maxWidth: 600).padding(20).frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private func completionStat(_ title: String, value: String, symbol: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 19, weight: .semibold)).foregroundStyle(AppColors.primary)
            Text(title).font(.caption).foregroundStyle(AppColors.secondaryText)
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
        }
        .frame(maxWidth: .infinity)
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
            .foregroundStyle(selected ? AppColors.primary : AppColors.text)
            .padding(11).frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? AppColors.accent.opacity(0.65) : AppColors.background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? AppColors.primary : AppColors.border, lineWidth: selected ? 1.5 : 1))
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
    let exercises: [FocusExercise]
    let completedExercises: Int
    let currentIndex: Int

    var body: some View {
        List {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                HStack(spacing: 12) {
                        Image(systemName: index < completedExercises ? "checkmark.circle.fill" : exercise.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(index < completedExercises ? AppColors.primary : AppColors.secondary)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(AppColors.text)
                            Text(exercise.instructionSummary).font(.caption).foregroundStyle(AppColors.secondaryText)
                        }
                        Spacer()
                        if index == currentIndex {
                            Text("Current").font(.caption2.bold()).foregroundStyle(AppColors.primary)
                        }
                    }
                .padding(.vertical, 5)
                .listRowBackground(AppColors.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Exercise List")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppColors.primary)
    }
}

// Esta tarjeta resume el tiempo estimado y el progreso.
struct WorkoutStatsView: View {
    @ObservedObject var viewModel: FocusWorkoutViewModel

    var body: some View {
        HStack(spacing: 0) {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                stat(symbol: "clock", title: "Time Remaining", value: viewModel.remainingWorkoutText,
                     detail: viewModel.workoutDelayText)
            }
            divider
            stat(symbol: "chart.bar.fill", title: "Progress", value: viewModel.progressLabel)
        }
        .padding(.vertical, 13).appCard()
    }

    private func stat(symbol: String, title: String, value: String, detail: String? = nil) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 21, weight: .semibold)).foregroundStyle(AppColors.primary)
            Text(title).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
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
        Rectangle().fill(AppColors.border).frame(width: 1, height: 44)
    }
}
import SwiftUI

// Esta tarjeta muestra el ejercicio activo y su progreso por sets.
struct WorkoutSummaryCard: View {
    @ObservedObject var viewModel: FocusWorkoutViewModel

    private var exerciseTarget: String {
        if let repetitions = viewModel.currentExercise.repetitions { return "\(repetitions) reps" }
        if let duration = viewModel.currentExercise.durationSeconds { return "\(duration) sec" }
        return "Exercise"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 13) {
                Image(systemName: viewModel.currentExercise.symbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 54, height: 54)
                    .background(AppColors.accent.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.currentExercise.name)
                        .font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                    Text("\(exerciseTarget) · \(viewModel.setLabel)")
                        .font(.system(size: 14, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                }
                Spacer(minLength: 2)
            }
            HStack(spacing: 5) {
                ForEach(0..<max(viewModel.currentExercise.sets, 0), id: \.self) { index in
                    Capsule()
                        .fill(index < viewModel.currentSet ? AppColors.primary : AppColors.accent.opacity(0.65))
                        .frame(height: 7)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(viewModel.setLabel)
        }
        .padding(15).appCard()
    }
}
import SwiftUI

// Shows a randomly selected exercise animation and the current timer controls.
struct WorkoutTimerView: View {
    @ObservedObject var viewModel: FocusWorkoutViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animation = WorkoutAnimation.all.randomElement()!
    @State private var animationStartedAt = Date.now

    private static let animationFrameDuration = 0.8
    private static let timerFontSize: CGFloat = 34

    private var timerText: String? {
        if viewModel.isShowingRest {
            if viewModel.restTimeExpired {
                return String(format: "+%02d:%02d", viewModel.restOvertimeSeconds / 60, viewModel.restOvertimeSeconds % 60)
            }
            return String(format: "%02d:%02d", viewModel.remainingSeconds / 60, viewModel.remainingSeconds % 60)
        }
        if viewModel.currentExercise.durationSeconds != nil { return viewModel.currentTimeText }
        return nil
    }

    var body: some View {
        VStack(spacing: 10) {
            TimelineView(.periodic(from: .now, by: Self.animationFrameDuration)) { context in
                let displayedAnimation = viewModel.isShowingRest
                    ? (viewModel.restTimeExpired ? WorkoutAnimation.restOvertime : WorkoutAnimation.rest)
                    : animation
                let frameIndex = frameIndex(for: displayedAnimation, at: context.date)

                Image(displayedAnimation.frameName(frameIndex))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320)
                    .aspectRatio(1, contentMode: .fit)
                    .accessibilityLabel("Workout animation")
            }

            if !viewModel.isShowingRest {
                Group {
                    if viewModel.state == .paused || viewModel.elapsedTimerStart == nil {
                        Text(viewModel.elapsedWorkoutText)
                    } else if let start = viewModel.elapsedTimerStart {
                        Text(start, style: .timer)
                    }
                }
                .font(.system(size: Self.timerFontSize, weight: .medium, design: .rounded))
                .monospacedDigit().foregroundStyle(AppColors.text)
                .lineLimit(1).minimumScaleFactor(0.5).frame(minHeight: 41)
            }

            if let timerText {
                Text(viewModel.stateTitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                Text(timerText)
                    .font(.system(size: Self.timerFontSize, weight: .medium, design: .rounded))
                    .monospacedDigit().foregroundStyle(viewModel.isShowingRest && viewModel.restTimeExpired ? Color.red : AppColors.text)
                    .lineLimit(1).minimumScaleFactor(0.5).frame(minHeight: 41)
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: viewModel.exerciseIndex) { _, _ in
            animation = WorkoutAnimation.all.randomElement()!
            animationStartedAt = .now
        }
        .onChange(of: viewModel.state) { _, _ in
            animationStartedAt = .now
        }
        .onChange(of: viewModel.restTimeExpired) { _, _ in
            animationStartedAt = .now
        }
        .onAppear {
            animationStartedAt = .now
        }
    }

    private func frameIndex(for animation: WorkoutAnimation, at date: Date) -> Int {
        guard !reduceMotion, viewModel.state != .paused else { return 0 }

        let elapsed = max(0, date.timeIntervalSince(animationStartedAt))
        if animation.repeats {
            return Int(elapsed / Self.animationFrameDuration) % 2
        }
        return elapsed >= Self.animationFrameDuration ? 1 : 0
    }
}

private struct WorkoutAnimation {
    let first: String
    let second: String
    var repeats = true

    static let rest = WorkoutAnimation(first: "WorkoutAnimationRest1", second: "WorkoutAnimationRest2")
    static let restOvertime = WorkoutAnimation(
        first: "WorkoutAnimationMelt1",
        second: "WorkoutAnimationMelt2",
        repeats: false
    )

    static let all: [WorkoutAnimation] = [
        .init(first: "WorkoutAnimationCurl1", second: "WorkoutAnimationCurl2"),
        .init(first: "WorkoutAnimationCycle1", second: "WorkoutAnimationCycle2"),
        .init(first: "WorkoutAnimationLegPress1", second: "WorkoutAnimationLegPress2"),
        .init(first: "WorkoutAnimationPulley1", second: "WorkoutAnimationPulley2"),
        .init(first: "WorkoutAnimationTreadmill1", second: "WorkoutAnimationTreadmill2")
    ]

    func frameName(_ index: Int) -> String {
        index == 0 ? first : second
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
    let symbol: String
    let label: String
    var isEmphasized = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(isEmphasized ? AppColors.primary : AppColors.secondary)
                .frame(width: 58, height: 58)
                .background(AppColors.accent.opacity(0.5), in: Circle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(label)
    }
}

// Este botón ancho marca acciones importantes en la sesión.
struct WorkoutPrimaryAction: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.surface)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(AppColors.primary, in: Capsule())
                .overlay(Capsule().stroke(AppColors.secondary, lineWidth: 1))
                .shadow(color: AppColors.secondary.opacity(0.14), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(SoftPressStyle())
    }
}
