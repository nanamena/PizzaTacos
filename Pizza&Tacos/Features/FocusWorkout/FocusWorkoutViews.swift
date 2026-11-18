import SwiftUI

// Esta vista presenta el entrenamiento activo y conecta sus controles con el ViewModel.
struct FocusWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FocusWorkoutViewModel
    private let historyStore: WorkoutHistoryStore

    init(routine: Routine, historyStore: WorkoutHistoryStore) {
        self.historyStore = historyStore
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
        .onAppear { viewModel.startWorkout() }
        .sheet(item: $viewModel.presentedSheet) { route in
            NavigationStack {
                switch route {
                case .exerciseList:
                    WorkoutExerciseListView(exercises: viewModel.exercises,
                                            completedExercises: viewModel.completedExercises,
                                            currentIndex: viewModel.exerciseIndex)
                case .exerciseDetail(let exercise):
                    ExerciseDetailsView(exercise: exercise)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("End this workout?", isPresented: $viewModel.showingEndConfirmation, titleVisibility: .visible) {
            Button("Keep Workout Running", role: .cancel) { }
            Button("End Workout", role: .destructive) { viewModel.endWorkout() }
        } message: {
            Text("Your completed sets will be included in this session.")
        }
        .sensoryFeedback(.success, trigger: viewModel.completedSets)
    }

    private var activeWorkoutScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 15) {
                header
                WorkoutSummaryCard(viewModel: viewModel)
                WorkoutTimerView(viewModel: viewModel)
                WorkoutStatsView(viewModel: viewModel)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Up Next").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                    NextExerciseCard(exercise: viewModel.nextExercise, action: viewModel.showExerciseList)
                }

                WorkoutFlowView(viewModel: viewModel)
                actionControls
            }
            .frame(maxWidth: 600).padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 18)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavigationBar(selection: .constant(.workouts), isInteractive: false)
        }
    }

    // Este encabezado permite volver con confirmación y acceder al menú de la sesión.
    private var header: some View {
        HStack {
            Button { viewModel.showingEndConfirmation = true } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(AppColors.text)
                    .frame(width: 48, height: 48).background(AppColors.accent.opacity(0.42), in: Circle())
            }
            .accessibilityLabel("End workout and go back")
            Spacer()
            Text("Workout").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
            Spacer()
            Menu {
                Button(viewModel.state == .paused ? "Resume Workout" : "Pause Workout", systemImage: viewModel.state == .paused ? "play.fill" : "pause.fill") {
                    if viewModel.state == .paused { viewModel.resumeWorkout() } else { viewModel.pauseWorkout() }
                }
                Button("Restart Workout", systemImage: "arrow.counterclockwise") { viewModel.restartWorkout() }
                Button("End Workout", systemImage: "xmark", role: .destructive) { viewModel.showingEndConfirmation = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19, weight: .bold)).foregroundStyle(AppColors.text)
                    .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Workout options")
        }
        .frame(height: 52)
    }

    // Este grupo muestra controles relevantes según la fase del ejercicio.
    @ViewBuilder
    private var actionControls: some View {
        if viewModel.state == .resting {
            HStack(spacing: 11) {
                WorkoutActionButton(symbol: "arrow.counterclockwise", label: "Restart Rest", action: viewModel.restartRest)
                WorkoutPrimaryAction(title: "Skip Rest", symbol: "forward.end.fill", action: viewModel.skipRest)
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

// Esta fila muestra el siguiente ejercicio y abre sus detalles sin saltar el flujo.
struct NextExerciseCard: View {
    let exercise: FocusExercise?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: exercise?.symbol ?? "checkmark")
                    .font(.system(size: 25, weight: .medium)).foregroundStyle(AppColors.primary)
                    .frame(width: 62, height: 62).background(AppColors.accent.opacity(0.55), in: RoundedRectangle(cornerRadius: 19))
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise?.name ?? "Workout Complete")
                        .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                    Text(exercise?.instructionSummary ?? "All planned exercises are complete")
                        .font(.system(size: 13, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                }
                Spacer(minLength: 3)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.secondary)
            }
            .padding(13).appCard()
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityHint("View exercise details")
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

                MascotWorkoutView(accessibilityDescription: "ModiFiT mascot celebrating your workout")
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
                NavigationLink {
                    ExerciseDetailsView(exercise: exercise)
                } label: {
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
                }
                .listRowBackground(AppColors.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Exercise List")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppColors.primary)
    }
}

// Esta pantalla detalla el ejercicio seleccionado sin modificar el orden de la sesión.
struct ExerciseDetailsView: View {
    let exercise: FocusExercise

    var body: some View {
        VStack(spacing: 17) {
            Image(systemName: exercise.symbol)
                .font(.system(size: 38, weight: .medium)).foregroundStyle(AppColors.primary)
                .frame(width: 82, height: 82).background(AppColors.accent.opacity(0.6), in: RoundedRectangle(cornerRadius: 25))
            Text(exercise.name).font(.system(size: 25, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
            Text(exercise.instructionSummary).font(.system(size: 16, design: .rounded)).foregroundStyle(AppColors.secondaryText)
            Label("\(exercise.restSeconds) sec rest", systemImage: "stopwatch")
                .font(.subheadline).foregroundStyle(AppColors.secondary)
            Text("Exercise details are for reference. ModiFiT does not change your training plan.")
                .font(.footnote).foregroundStyle(AppColors.secondaryText).multilineTextAlignment(.center)
                .padding(.top, 6)
        }
        .padding(26).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }
}
import SwiftUI

// Esta línea de tiempo distingue ejercicios completados, actual y próximos.
struct WorkoutFlowView: View {
    @ObservedObject var viewModel: FocusWorkoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Workout Flow").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                Spacer()
                Button("See All") { viewModel.showExerciseList() }
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(AppColors.primary)
                    .accessibilityHint("Open the full exercise list")
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(viewModel.exercises.indices, id: \.self) { index in
                            if index > 0 {
                                Rectangle().fill(index <= viewModel.completedExercises ? AppColors.primary.opacity(0.48) : AppColors.border)
                                    .frame(width: 25, height: 3).padding(.top, 17)
                            }
                            flowStep(index: index)
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 5).padding(.vertical, 5)
                }
                .onAppear { proxy.scrollTo(viewModel.exerciseIndex, anchor: .center) }
                .onChange(of: viewModel.exerciseIndex) { _, index in
                    withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(index, anchor: .center) }
                }
            }
        }
        .padding(14).appCard()
    }

    private func flowStep(index: Int) -> some View {
        let exercise = viewModel.exercises[index]
        let completed = index < viewModel.completedExercises
        let current = index == viewModel.exerciseIndex && viewModel.state != .completed

        return Button { viewModel.showDetails(for: exercise) } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(completed ? AppColors.primary : AppColors.accent.opacity(current ? 0.82 : 0.42))
                        .frame(width: 36, height: 36)
                    Image(systemName: completed ? "checkmark" : exercise.symbol)
                        .font(.system(size: completed ? 14 : 14, weight: .bold))
                        .foregroundStyle(completed ? AppColors.surface : AppColors.primary)
                }
                Text(exercise.name)
                    .font(.system(size: 10, weight: current ? .bold : .medium, design: .rounded))
                    .foregroundStyle(current || completed ? AppColors.text : AppColors.secondaryText)
                    .multilineTextAlignment(.center).lineLimit(2).frame(width: 66).frame(minHeight: 25)
            }
            .frame(width: 76).frame(minHeight: 79)
            .padding(.horizontal, current ? 4 : 0)
            .overlay {
                if current {
                    RoundedRectangle(cornerRadius: 19).stroke(AppColors.primary, lineWidth: 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 19))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(exercise.name), \(completed ? "completed" : current ? "current exercise" : "upcoming")")
        .accessibilityHint("View exercise details")
    }
}
import SwiftUI

// Esta tarjeta resume el tiempo estimado, el progreso y las calorías disponibles.
struct WorkoutStatsView: View {
    @ObservedObject var viewModel: FocusWorkoutViewModel

    var body: some View {
        HStack(spacing: 0) {
            stat(symbol: "clock", title: "Time Remaining", value: viewModel.remainingWorkoutText)
            divider
            stat(symbol: "chart.bar.fill", title: "Progress", value: viewModel.progressLabel)
            divider
            stat(symbol: "flame.fill", title: "Calories", value: viewModel.currentCaloriesText)
        }
        .padding(.vertical, 13).appCard()
    }

    private func stat(symbol: String, title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 21, weight: .semibold)).foregroundStyle(AppColors.primary)
            Text(title).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle().fill(AppColors.border).frame(width: 1, height: 44)
    }
}
import SwiftUI

// Esta tarjeta resume la rutina activa y muestra el progreso por ejercicios.
struct WorkoutSummaryCard: View {
    @ObservedObject var viewModel: FocusWorkoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 13) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 54, height: 54)
                    .background(AppColors.accent.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.routine.name)
                        .font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                    Text("Workout \(viewModel.currentExerciseNumber) of \(viewModel.exercises.count)")
                        .font(.system(size: 14, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                }
                Spacer(minLength: 2)
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(AppColors.primary)
                    Text(viewModel.currentCaloriesText).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(AppColors.text)
                }
                .padding(.horizontal, 11).padding(.vertical, 10)
                .background(AppColors.accent.opacity(0.42), in: Capsule())
                .accessibilityLabel("Estimated calories unavailable")
            }
            HStack(spacing: 5) {
                ForEach(viewModel.exercises.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < viewModel.completedExercises ? AppColors.primary : AppColors.accent.opacity(0.65))
                        .frame(height: 7)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(viewModel.completedExercises) of \(viewModel.exercises.count) exercises completed")
        }
        .padding(15).appCard()
    }
}
import SwiftUI

// Esta vista muestra el estado del set y el temporizador circular central.
struct WorkoutTimerView: View {
    @ObservedObject var viewModel: FocusWorkoutViewModel

    private var progress: Double {
        guard viewModel.countdownDuration > 0 else { return 1 }
        return min(1, max(0, Double(viewModel.remainingSeconds) / Double(viewModel.countdownDuration)))
    }

    private var timerSymbol: String {
        viewModel.state == .resting || (viewModel.state == .paused && viewModel.remainingSeconds > 0) ? "stopwatch" : "dumbbell.fill"
    }

    private var detailLine: String {
        if viewModel.state == .resting { return "Next: \(viewModel.currentExercise.name)" }
        return viewModel.setLabel
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CircularTimerView(progress: progress) {
                VStack(spacing: 7) {
                    Image(systemName: timerSymbol)
                        .font(.system(size: 34, weight: .semibold)).foregroundStyle(AppColors.primary)
                    Text(viewModel.stateTitle)
                        .font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                        .multilineTextAlignment(.center)
                    if viewModel.state == .exercising || (viewModel.state == .paused && viewModel.pausedStateIsTimedExercise) {
                        Text(viewModel.currentExercise.name)
                            .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Text(viewModel.currentTimeText)
                        .font(.system(size: viewModel.currentTimeText.count > 6 ? 43 : 51, weight: .bold, design: .rounded))
                        .monospacedDigit().tracking(-1.4).foregroundStyle(AppColors.text)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text(detailLine)
                        .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Button {
                        if viewModel.state == .paused { viewModel.resumeWorkout() }
                        else { viewModel.pauseWorkout() }
                    } label: {
                        Image(systemName: viewModel.state == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 20, weight: .bold)).foregroundStyle(AppColors.primary)
                            .frame(width: 118, height: 54).background(AppColors.accent.opacity(0.48), in: Capsule())
                    }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityLabel(viewModel.state == .paused ? "Resume workout" : "Pause workout")
                    .padding(.top, 3)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 370)
            .frame(maxWidth: .infinity)

            MascotWorkoutView(accessibilityDescription: mascotDescription)
                .frame(width: 112, height: 138)
                .offset(x: -3, y: 8)
                .accessibilityHidden(false)
        }
        .frame(maxWidth: 390)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private var mascotDescription: String {
        switch viewModel.state {
        case .resting, .paused: "ModiFiT mascot resting beside the timer"
        case .exercising, .ready: "ModiFiT mascot cheering during the workout"
        case .completed: "ModiFiT mascot celebrating the workout"
        }
    }
}

// Este anillo usa un trazo sólido y comunica el tiempo restante sin degradados.
struct CircularTimerView<Content: View>: View {
    let progress: Double
    @ViewBuilder let content: Content

    init(progress: Double, @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.content = content()
    }

    var body: some View {
        ZStack {
            Circle().stroke(AppColors.accent.opacity(0.62), lineWidth: 15)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: progress)
            content.padding(32)
        }
        .padding(8)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
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
