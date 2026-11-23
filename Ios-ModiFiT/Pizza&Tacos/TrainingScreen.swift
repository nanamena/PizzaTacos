import SwiftUI

struct TrainingScreen: View {
    @Environment(\.appColors) private var appColors

    let routine: Routine
    let onStartWorkout: (Routine) -> Void
    private let watchSelectionRequest: WatchExerciseSelectionRequest?
    private let onSendSelectionToWatch: ((WatchExerciseSelectionResponse) -> Bool)?
    private let onCancelWatchSelection: ((UUID) -> Void)?
    @State private var viewModel: TrainingViewModel
    @State private var showingWatchSendError = false
    @State private var finishedWatchSelection = false

    private var isSelectingForWatch: Bool { watchSelectionRequest != nil }

    init(routine: Routine,
         onStartWorkout: @escaping (Routine) -> Void = { _ in },
         watchSelectionRequest: WatchExerciseSelectionRequest? = nil,
         onSendSelectionToWatch: ((WatchExerciseSelectionResponse) -> Bool)? = nil,
         onCancelWatchSelection: ((UUID) -> Void)? = nil) {
        self.routine = routine
        self.onStartWorkout = onStartWorkout
        self.watchSelectionRequest = watchSelectionRequest
        self.onSendSelectionToWatch = onSendSelectionToWatch
        self.onCancelWatchSelection = onCancelWatchSelection
        _viewModel = State(initialValue: TrainingViewModel(exercises: routine.exercises))
    }

    var body: some View {
        List {
            Section {
                TimeSummaryRow(minutes: viewModel.totalMinutes)
            }
            .listRowBackground(appColors.card)

            exerciseSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(appColors.background.ignoresSafeArea())
        .foregroundStyle(appColors.text)
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if isSelectingForWatch {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: cancelWatchSelection)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(viewModel.allSelected ? "Deselect All" : "Select All") {
                    withAnimation(.snappy) { viewModel.toggleAll() }
                }
                .disabled(viewModel.exercises.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            StartButton(isEnabled: viewModel.hasSelection,
                        title: startButtonTitle) {
                handleStartButtonTap()
            }
        }
        .alert("Couldn’t send selection", isPresented: $showingWatchSendError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Keep Apple Watch nearby and try again.")
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedIDs)
    }

    private func cancelWatchSelection() {
        guard let request = watchSelectionRequest, !finishedWatchSelection else { return }
        finishedWatchSelection = true
        onCancelWatchSelection?(request.id)
    }

    private func exerciseRow(_ exercise: FocusExercise, minutes: Int) -> some View {
        ExerciseRow(
            exercise: exercise,
            minutes: minutes,
            isSelected: viewModel.selectedIDs.contains(exercise.id),
            onToggle: { toggleExercise(exercise) }
        )
    }

    private func toggleExercise(_ exercise: FocusExercise) {
        withAnimation(.snappy) { viewModel.toggle(exercise) }
    }

    private var startButtonTitle: String {
        isSelectingForWatch ? "Send to Apple Watch" : "Start Workout"
    }

    private var exerciseSection: some View {
        let minutes = viewModel.displayedMinutes
        return Section("Exercises") {
            ForEach(viewModel.exercises) { exercise in
                exerciseRow(exercise, minutes: minutes[exercise.id] ?? 0)
            }
        }
        .listRowBackground(appColors.card)
    }

    private func handleStartButtonTap() {
        if let request = watchSelectionRequest {
            guard !finishedWatchSelection else { return }
            let response = WatchExerciseSelectionResponse(
                requestID: request.id,
                selectedExerciseIDs: viewModel.selectedExercises.map(\.id),
                healthMode: nil
            )
            finishedWatchSelection = true
            if onSendSelectionToWatch?(response) != true {
                finishedWatchSelection = false
                showingWatchSendError = true
            }
        } else {
            let exercises = viewModel.selectedExercises
            guard !exercises.isEmpty else { return }
            onStartWorkout(Routine(id: routine.id, name: routine.name, symbol: routine.symbol,
                                   exercises: exercises, createdAt: routine.createdAt))
        }
    }
}

// MARK: - Time summary

private struct TimeSummaryRow: View {
    @Environment(\.appColors) private var appColors

    let minutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Estimated time")
                .font(.subheadline)
                .foregroundStyle(appColors.secondaryText)
            Text("\(minutes) min")
                .font(.largeTitle.bold())
                .foregroundStyle(appColors.text)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(minutes)))
                .animation(.snappy, value: minutes)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Exercise row

private struct ExerciseRow: View {
    @Environment(\.appColors) private var appColors

    let exercise: FocusExercise
    let minutes: Int
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? appColors.primary : appColors.secondary)
                    .symbolEffect(.bounce, value: isSelected)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.body)
                        .foregroundStyle(appColors.text)
                    Text("\(exercise.instructionSummary) · \(exercise.restSeconds)s rest")
                        .font(.subheadline)
                        .foregroundStyle(appColors.secondaryText)
                }

                Spacer(minLength: 8)

                Text("\(minutes) min")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(appColors.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(
            "\(exercise.name), \(exercise.instructionSummary), \(exercise.restSeconds) seconds rest, \(minutes) minutes"
        )
    }
}

// MARK: - Primary button

private struct StartButton: View {
    @Environment(\.appColors) private var appColors

    let isEnabled: Bool
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .buttonSizing(.flexible)
        .controlSize(.large)
        .tint(appColors.primary)
        .disabled(!isEnabled)
        .frame(maxWidth: 400)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        TrainingScreen(
            routine: Routine(
                id: "preview-workout",
                name: "Preview Workout",
                symbol: "dumbbell.fill",
                exercises: [
                    FocusExercise(id: "preview-exercise", name: "Bench Press", sets: 3,
                                  repetitions: 10, durationSeconds: nil, restSeconds: 60,
                                  symbol: "dumbbell.fill")
                ]
            )
        )
    }
    .modifier(AppTheme(palette: .terracotta))
}
