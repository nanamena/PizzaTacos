import SwiftUI

struct FocusWorkoutSetView: View {
    let routine: Routine
    let workout: LiveWorkoutSnapshot?
    var actionsEnabled = true
    var showsWatchConflict = false
    var showsHealthFailure = false
    var commandRejected = false
    var onBrowseRoutines: (() -> Void)?
    let timing: (Date) -> (remaining: String, delay: String?)
    let onAction: (LiveWorkoutAction) -> Void

    @Environment(\.appColors) private var appColors
    @State private var showingEndConfirmation = false
    @State private var showingExercises = false

    private var position: WorkoutPosition { workout?.position ?? WorkoutPosition() }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 15) {
                if showsWatchConflict {
                    Label("A separate workout is running on Apple Watch.", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                }
                if let onBrowseRoutines {
                    Label("Connection lost", systemImage: "link.badge.plus")
                        .font(.footnote)
                    Button("Browse Routines", action: onBrowseRoutines)
                        .buttonStyle(.bordered)
                } else if commandRejected {
                    Text("Couldn’t apply that action. Try again.")
                        .font(.footnote)
                        .foregroundStyle(appColors.secondaryText)
                }

                WorkoutSummaryCard(exercise: routine.exercises[position.exerciseIndex], currentSet: position.set)
                WorkoutTimerView(workout: workout)
                WorkoutStatsView(progressLabel: "\(position.exerciseIndex + 1) of \(routine.exercises.count)", timing: timing)

                if showsHealthFailure {
                    Label("Apple Health is unavailable for this workout. Your session continues locally.", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(appColors.secondaryText)
                }
            }
            .frame(maxWidth: 600).padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 18)
            .frame(maxWidth: .infinity)
        }
        .background(appColors.background.ignoresSafeArea())
        .tint(appColors.primary)
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar, .tabBar)
        .toolbar {
            if workout != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingEndConfirmation = true } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(appColors.primary)
                    }
                    .disabled(!actionsEnabled)
                    .accessibilityLabel("End workout")
                    .confirmationDialog("End this workout?", isPresented: $showingEndConfirmation, titleVisibility: .visible) {
                        Button("Keep Workout Running", role: .cancel) {}
                        Button("End Workout", role: .destructive) { perform(.discard) }
                            .disabled(!actionsEnabled)
                    } message: {
                        Text("This workout won't be saved to your history or Apple Health.")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionControls
                .frame(maxWidth: 600)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(appColors.background)
        }
        .sheet(isPresented: $showingExercises) {
            NavigationStack {
                WorkoutExerciseListView(exercises: routine.exercises,
                                        completedExercises: position.completedExercises,
                                        currentIndex: position.exerciseIndex)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var actionControls: some View {
        if let workout {
            HStack(spacing: workout.resting || workout.pausedAt != nil ? 11 : 12) {
                if workout.pausedAt != nil {
                    WorkoutPrimaryAction(title: "Resume", symbol: "play.fill") { perform(.resume) }
                        .disabled(!actionsEnabled)
                } else {
                    if workout.resting {
                        WorkoutPrimaryAction(
                            title: position.set == 1 ? "Next Exercise" : "Next Set",
                            symbol: "forward.end.fill"
                        ) { perform(.skipRest) }
                        .disabled(!actionsEnabled)
                    } else {
                        WorkoutPrimaryAction(title: "Finish Set", symbol: "checkmark") { perform(.finishSet) }
                            .disabled(!actionsEnabled)
                    }

                    WorkoutActionButton(symbol: "pause.fill", label: "Pause") { perform(.pause) }
                        .disabled(!actionsEnabled)
                }
                WorkoutActionButton(symbol: "list.bullet", label: "Exercise List") { showingExercises = true }
            }
        } else {
            SwiftUI.ProgressView("Preparing workout")
                .frame(maxWidth: .infinity, minHeight: 50)
        }
    }

    private func perform(_ action: LiveWorkoutAction) {
        guard actionsEnabled, let workout, action.isAvailable(in: workout) else { return }
        onAction(action)
    }
}
