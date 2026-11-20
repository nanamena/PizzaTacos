import SwiftUI

struct TrainingScreen: View {
    @Environment(\.appColors) private var appColors

    let routine: Routine
    let historyStore: WorkoutHistoryStore
    let workoutLibrary: WorkoutLibraryStore
    let onWorkoutCompleted: () -> Void
    @State private var viewModel: TrainingViewModel
    @State private var activeRoutine: Routine?
    @State private var activityCategory: WorkoutActivityCategory?
    @State private var showingCategoryPrompt = false
    @State private var showingHealthAccessHelp = false
    @ObservedObject private var healthAccess = AppleHealthAccess.shared

    init(routine: Routine, historyStore: WorkoutHistoryStore, workoutLibrary: WorkoutLibraryStore,
         onWorkoutCompleted: @escaping () -> Void = {}) {
        self.routine = routine
        self.historyStore = historyStore
        self.workoutLibrary = workoutLibrary
        self.onWorkoutCompleted = onWorkoutCompleted
        _viewModel = State(initialValue: TrainingViewModel(exercises: routine.exercises))
        _activityCategory = State(initialValue: routine.activityCategory)
    }

    var body: some View {
        List {
            Section {
                TimeSummaryRow(minutes: viewModel.totalMinutes)
            }
            .listRowBackground(appColors.card)

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
            .listRowBackground(appColors.card)

            Section("Apple Health") {
                if healthAccess.savesWorkouts {
                    Picker("Workout type", selection: Binding(
                        get: { activityCategory },
                        set: saveActivityCategory
                    )) {
                        Text("Choose a type").tag(nil as WorkoutActivityCategory?)
                        ForEach(WorkoutActivityCategory.allCases) { category in
                            Text(category.title).tag(category as WorkoutActivityCategory?)
                        }
                    }
                    Text("Choose the Apple activity type before recording this workout in Health.")
                        .font(.footnote)
                        .foregroundStyle(appColors.secondaryText)
                } else {
                    Button("Connect Apple Health") {
                        Task {
                            if !(await healthAccess.enable()) { showingHealthAccessHelp = true }
                        }
                    }
                    .disabled(!healthAccess.isAvailable)
                    Text("Completed workouts can use Apple's activity and energy data. ModiFiT works without Health access.")
                        .font(.footnote)
                        .foregroundStyle(appColors.secondaryText)
                }
            }
            .listRowBackground(appColors.card)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(appColors.background.ignoresSafeArea())
        .foregroundStyle(appColors.text)
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
                if healthAccess.savesWorkouts && activityCategory == nil {
                    showingCategoryPrompt = true
                } else {
                    beginWorkout(recordInHealth: healthAccess.savesWorkouts)
                }
            }
        }
        .confirmationDialog("Choose an Apple Health workout type", isPresented: $showingCategoryPrompt) {
            Button("Start Without Apple Health") { beginWorkout(recordInHealth: false) }
            Button("Choose Workout Type", role: .cancel) { }
        } message: {
            Text("Select a type above to save this session in Apple Health, or continue locally.")
        }
        .alert("Apple Health access", isPresented: $showingHealthAccessHelp) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Open the Health app and review ModiFiT's Workout permissions.")
        }
        .task { healthAccess.refresh() }
        .navigationDestination(item: $activeRoutine) { activeRoutine in
            FocusWorkoutView(routine: activeRoutine, historyStore: historyStore, onWorkoutCompleted: onWorkoutCompleted)
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedIDs)
    }

    private func saveActivityCategory(_ category: WorkoutActivityCategory?) {
        activityCategory = category
        var updated = routine
        updated.activityCategory = category
        workoutLibrary.updateRoutine(updated)
    }

    private func beginWorkout(recordInHealth: Bool) {
        let exercises = viewModel.selectedExercises
        guard !exercises.isEmpty else { return }
        activeRoutine = Routine(id: routine.id, name: routine.name, symbol: routine.symbol,
                                exercises: exercises, createdAt: routine.createdAt,
                                activityCategory: recordInHealth ? activityCategory : nil)
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
            ),
            historyStore: WorkoutHistoryStore(),
            workoutLibrary: WorkoutLibraryStore()
        )
    }
    .modifier(AppTheme(palette: .terracotta))
}
