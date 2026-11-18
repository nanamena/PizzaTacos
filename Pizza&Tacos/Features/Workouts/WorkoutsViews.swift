import SwiftUI

private enum RoutineSortOrder: Hashable {
    case created
    case lastUsed
    case duration
}

private enum RoutineDurationFilter: Hashable {
    case any
    case under30Minutes
    case from30To60Minutes
    case over60Minutes

    var label: String {
        switch self {
        case .any: return "Any Duration"
        case .under30Minutes: return "Under 30 min"
        case .from30To60Minutes: return "30–60 min"
        case .over60Minutes: return "Over 60 min"
        }
    }

    func includes(_ minutes: Int) -> Bool {
        switch self {
        case .any: return true
        case .under30Minutes: return minutes < 30
        case .from30To60Minutes: return (30...60).contains(minutes)
        case .over60Minutes: return minutes > 60
        }
    }
}

// Esta vista compone la pantalla inicial Workouts con el diseño de referencia ModiFiT.
struct WorkoutsView: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    let historyStore: WorkoutHistoryStore
    @ObservedObject var workoutLibrary: WorkoutLibraryStore
    @ObservedObject var workoutPreferences: WorkoutPreferencesStore
    @State private var searchText = ""
    @State private var sortOrder = RoutineSortOrder.created
    @State private var durationFilter = RoutineDurationFilter.any
    @State private var editingRoutine: Routine?
    @State private var deletingRoutine: Routine?
    @State private var workoutEditor: WorkoutEditorRequest?

    private var visibleRoutines: [Routine] {
        let routines = workoutLibrary.sampleRoutines + workoutLibrary.standaloneRoutines
        return routines.filter { routine in
            let matchesDuration = durationFilter.includes(routine.estimatedMinutes)
            return matchesDuration && (searchText.isEmpty || routine.name.localizedCaseInsensitiveContains(searchText))
        }.sorted { first, second in
            if sortOrder == .duration { return first.estimatedMinutes < second.estimatedMinutes }
            if sortOrder == .lastUsed {
                let firstDate = historyStore.records.filter { $0.routineID == first.id }.map(\.completedAt).max() ?? .distantPast
                let secondDate = historyStore.records.filter { $0.routineID == second.id }.map(\.completedAt).max() ?? .distantPast
                return firstDate > secondDate
            }
            return first.createdAt > second.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 25) {
                    WorkoutHeaderView(onAdd: viewModel.presentAddWorkout)
                    FeaturedWorkoutCard(workout: workoutLibrary.featuredWorkout)
                    if let plan = workoutLibrary.activePlan {
                        TrainingPlanRow(name: plan.name, isActive: workoutLibrary.isPlanActive) {
                            workoutLibrary.setPlanActive(!workoutLibrary.isPlanActive)
                        }
                    }
                    RoutinesSection(routines: visibleRoutines, searchText: searchText, sortOrder: $sortOrder,
                                    durationFilter: $durationFilter,
                                    onEdit: { editingRoutine = $0 }, onDelete: { deletingRoutine = $0 })
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Workouts")
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search routines")
            .navigationDestination(for: Routine.self) { routine in
                TrainingScreen(routine: routine, historyStore: historyStore) {
                    workoutLibrary.markCompleted(routine.id)
                }
            }
            .navigationDestination(item: $workoutEditor) { request in
                CreateWorkoutView(routine: request.routine,
                                  defaultSets: workoutPreferences.defaultSets,
                                  defaultRepetitions: workoutPreferences.defaultRepetitions,
                                  defaultRestSeconds: workoutPreferences.defaultRestSeconds) { name, exercises in
                    let routine = Routine(id: request.routine?.id ?? UUID().uuidString,
                                          name: name,
                                          symbol: request.routine?.symbol ?? "dumbbell.fill",
                                          exercises: exercises.map { $0.makeFocusExercise() },
                                          createdAt: request.routine?.createdAt ?? Date())
                    if request.routine == nil {
                        workoutLibrary.saveRoutine(routine)
                    } else {
                        workoutLibrary.updateRoutine(routine)
                    }
                }
            }
            .alert("Delete \(deletingRoutine?.name ?? "routine")?", item: $deletingRoutine) { routine in
                Button("Delete", role: .destructive) { workoutLibrary.deleteRoutine(routine.id) }
                Button("Cancel", role: .cancel) { }
            } message: { routine in
                Text("This removes the routine from your library. Completed workouts stay in your history.")
            }
        }
        .onChange(of: viewModel.isManualWorkoutRequested) { _, requested in
            guard requested else { return }
            viewModel.isManualWorkoutRequested = false
            workoutEditor = WorkoutEditorRequest(routine: nil)
        }
        .onChange(of: editingRoutine) { _, routine in
            if let routine { workoutEditor = WorkoutEditorRequest(routine: routine) }
        }
    }
}

private struct WorkoutEditorRequest: Identifiable, Hashable {
    let id = UUID()
    let routine: Routine?
}

private struct TrainingPlanRow: View {
    let name: String
    let isActive: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Training Plan").font(.headline)
                Text(name).font(.subheadline).foregroundStyle(.secondary)
                Label(isActive ? "Active" : "Paused", systemImage: isActive ? "play.circle.fill" : "pause.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(isActive ? "Pause" : "Resume", action: onToggle)
                .buttonStyle(.bordered)
        }
        .padding(16).appCard()
    }
}

// Este encabezado muestra el título y la acción de añadir rutina.
private struct WorkoutHeaderView: View {
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("Workouts")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .tracking(-0.8)
                .foregroundStyle(AppColors.text)
            Spacer(minLength: 0)
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.terracotta)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .buttonSizing(.flexible)
            .controlSize(.small)
            .frame(width: 44, height: 44)
            .accessibilityLabel("Add workout")
        }
    }
}

private struct FeaturedWorkoutCard: View {
    let workout: WorkoutLibraryStore.FeaturedWorkout?

    @ViewBuilder
    var body: some View {
        if let workout {
            NavigationLink(value: workout.routine) {
                cardContent(workout: workout)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Start workout")
        } else {
            cardContent(workout: nil)
        }
    }

    private func cardContent(workout: WorkoutLibraryStore.FeaturedWorkout?) -> some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 10) {
                Text(workout?.planProgressLabel == nil ? "Latest Workout" : "Next Workout")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                if let workout {
                    let routine = workout.routine
                    Text(routine.name).font(.system(size: 18, weight: .medium, design: .rounded))
                    if let planProgressLabel = workout.planProgressLabel {
                        Text(planProgressLabel).font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    Label("\(routine.exerciseCount) exercises", systemImage: "dumbbell.fill")
                    Label("~ \(routine.estimatedMinutes) min (estimated)", systemImage: "timer")
                } else {
                    Text("Use + to add a workout or training plan.")
                        .font(.system(size: 13, design: .rounded))
                }
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)

            FloatingMascotView()
                .frame(width: 132, height: 158)
                .accessibilityHidden(false)
        }
        .padding(.leading, 23).padding(.trailing, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 178)
        .background(AppColors.primary, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: AppColors.secondary.opacity(0.16), radius: 12, x: 0, y: 7)
    }
}

// Esta sección muestra las rutinas de ejemplo en tarjetas accesibles y seleccionables.
private struct RoutinesSection: View {
    let routines: [Routine]
    let searchText: String
    @Binding var sortOrder: RoutineSortOrder
    @Binding var durationFilter: RoutineDurationFilter
    let onEdit: (Routine) -> Void
    let onDelete: (Routine) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("Routines")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .tracking(-0.45)
                    .foregroundStyle(AppColors.text)

                Spacer(minLength: 12)

                Menu("Filter and Sort", systemImage: "line.3.horizontal.decrease.circle") {
                    Picker("Sort By", selection: $sortOrder) {
                        Text("Newest").tag(RoutineSortOrder.created)
                        Text("Last Used").tag(RoutineSortOrder.lastUsed)
                        Text("Shortest").tag(RoutineSortOrder.duration)
                    }
                    Picker("Duration", selection: $durationFilter) {
                        Text("Any Duration").tag(RoutineDurationFilter.any)
                        Text("Under 30 min").tag(RoutineDurationFilter.under30Minutes)
                        Text("30–60 min").tag(RoutineDurationFilter.from30To60Minutes)
                        Text("Over 60 min").tag(RoutineDurationFilter.over60Minutes)
                    }
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(AppColors.primary)
                .frame(width: 44, height: 44)
                .accessibilityHint("Choose a duration filter and sort order for routines")
            }

            if durationFilter != .any {
                Label(durationFilter.label, systemImage: "line.3.horizontal.decrease")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Duration filter: \(durationFilter.label)")
            }

            if routines.isEmpty {
                if durationFilter != .any {
                    ContentUnavailableView {
                        Label("No Routines Match", systemImage: "line.3.horizontal.decrease")
                    } description: {
                        Text("Try changing the duration filter.")
                    } actions: {
                        Button("Clear Duration Filter") { durationFilter = .any }
                    }
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                ForEach(routines) { routine in
                    RoutineRowView(routine: routine, onEdit: { onEdit(routine) }, onDelete: { onDelete(routine) })
                }
            }
        }
    }
}

// Esta fila separa el símbolo, la descripción de la rutina y su indicador de navegación.
private struct RoutineRowView: View {
    let routine: Routine
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            NavigationLink(value: routine) {
                HStack(spacing: 16) {
                    Image(systemName: routine.symbol)
                        .font(.system(size: 29, weight: .medium))
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 66, height: 66)
                        .background(AppColors.accent.opacity(0.63), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(routine.name).font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                        Text("\(routine.exerciseCount) exercises · ~ \(routine.estimatedMinutes) min")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColors.secondaryText)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityHint("Choose exercises for this routine")

            Menu("Actions for \(routine.name)", systemImage: "ellipsis") {
                Button("Edit", systemImage: "pencil", action: onEdit)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .foregroundStyle(AppColors.coral)
            .frame(width: 44, height: 44)
            .accessibilityHint("Edit or delete this routine")
        }
        .padding(.leading, 17).padding(.trailing, 12).padding(.vertical, 17)
        .frame(maxWidth: .infinity, minHeight: 100)
        .appCard()
    }
}
import SwiftUI

// Esta hoja presenta las dos opciones de incorporación de rutinas indicadas en el diseño.
struct AddWorkoutSheet: View {
    @ObservedObject var workoutLibrary: WorkoutLibraryStore
    @Environment(\.dismiss) private var dismiss
    let onCreateManually: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 13) {
                Text("Choose how to add your training plan.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)

                FloatingMascotView().frame(height: 145).padding(.vertical, 2)

                NavigationLink {
                    WorkoutScannerView(activePlanName: workoutLibrary.activePlan?.name) { name, days in
                        workoutLibrary.savePlan(name: name, days: days)
                        dismiss()
                    }
                } label: {
                    AddWorkoutOption(title: "Scan Workout Plan", subtitle: "Take a photo or choose a file from your device.", symbol: "viewfinder")
                }.buttonStyle(SoftPressStyle())
                Button {
                    dismiss()
                    DispatchQueue.main.async(execute: onCreateManually)
                } label: {
                    AddWorkoutOption(title: "Create Manually", subtitle: "Add exercises, sets, reps and rest time.", symbol: "pencil")
                }
                .buttonStyle(SoftPressStyle())
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 21).padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Esta fila representa una acción de la hoja con una superficie táctil amplia.
private struct AddWorkoutOption: View {
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: symbol).font(.system(size: 22, weight: .medium)).foregroundStyle(AppColors.primary)
                .frame(width: 52, height: 52).background(AppColors.accent.opacity(0.62), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                Text(subtitle).font(.system(size: 13, weight: .regular, design: .rounded)).foregroundStyle(AppColors.secondaryText).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.secondary)
        }
        .padding(15).frame(maxWidth: .infinity, minHeight: 84).appCard()
    }
}

// Esta pantalla temporal confirma la opción elegida y deja preparada su ruta de navegación.
private struct AddWorkoutDestination: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 38)).foregroundStyle(AppColors.primary)
            Text(title).font(.title2.bold()).foregroundStyle(AppColors.text)
            Text("This feature will be available in a future update.")
                .font(.subheadline).foregroundStyle(AppColors.secondaryText).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}
