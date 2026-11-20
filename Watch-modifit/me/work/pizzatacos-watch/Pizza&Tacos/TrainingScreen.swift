import SwiftUI

struct TrainingScreen: View {
    let routine: Routine
    let historyStore: WorkoutHistoryStore
    let onWorkoutCompleted: () -> Void
    @State private var viewModel: TrainingViewModel
    @State private var activeRoutine: Routine?

    init(routine: Routine, historyStore: WorkoutHistoryStore, onWorkoutCompleted: @escaping () -> Void = {}) {
        self.routine = routine
        self.historyStore = historyStore
        self.onWorkoutCompleted = onWorkoutCompleted
        _viewModel = State(initialValue: TrainingViewModel(exercises: routine.exercises))
    }

    var body: some View {
        List {
            Section {
                TimeSummaryRow(minutes: viewModel.totalMinutes)
            }
            .listRowBackground(AppColors.card)

            Section("Exercises") {
                let minutes = viewModel.displayedMinutes
                ForEach(viewModel.exercises) { exercise in
                    ExerciseRow(
                        exercise: exercise,
                        minutes: minutes[exercise.id] ?? 0,
                        isSelected: viewModel.selectedIDs.contains(exercise.id),
                        onToggle: {
                            withAnimation(.snappy) { viewModel.toggle(exercise) }
                        }
                    )
                }
            }
            .listRowBackground(AppColors.card)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.background.ignoresSafeArea())
        .foregroundStyle(AppColors.text)
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(viewModel.allSelected ? "Deselect All" : "Select All") {
                    withAnimation(.snappy) { viewModel.toggleAll() }
                }
                .disabled(viewModel.exercises.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            StartButton(isEnabled: viewModel.hasSelection) {
                let exercises = viewModel.selectedExercises
                guard !exercises.isEmpty else { return }
                activeRoutine = Routine(id: routine.id, name: routine.name, symbol: routine.symbol, exercises: exercises)
            }
        }
        .navigationDestination(item: $activeRoutine) { activeRoutine in
            FocusWorkoutView(routine: activeRoutine, historyStore: historyStore, onWorkoutCompleted: onWorkoutCompleted)
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedIDs)
    }
}

// MARK: - Time summary

private struct TimeSummaryRow: View {
    let minutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Estimated time")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
            Text("\(minutes) min")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColors.text)
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
    let exercise: FocusExercise
    let minutes: Int
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppColors.primary : AppColors.secondary)
                    .symbolEffect(.bounce, value: isSelected)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.body)
                        .foregroundStyle(AppColors.text)
                    Text("\(exercise.instructionSummary) · \(exercise.restSeconds)s rest")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer(minLength: 8)

                Text("\(minutes) min")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.secondaryText)
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
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Start Workout")
                .font(.headline)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .buttonSizing(.flexible)
        .controlSize(.large)
        .tint(AppColors.primary)
        .disabled(!isEnabled)
        .frame(maxWidth: 400)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        TrainingScreen(routine: Routine.samples[0], historyStore: WorkoutHistoryStore())
    }
    .tint(AppColors.primary)
}
