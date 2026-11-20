import SwiftUI

private enum RoutineSortCriterion: String, CaseIterable, Identifiable {
    case created
    case duration
    case rating
    case lastUsed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .created: "Creation"
        case .duration: "Duration"
        case .rating: "Rating"
        case .lastUsed: "Last used"
        }
    }
}

private struct RoutineHistoryMetrics {
    var lastUsed: Date?
    private var feelingTotal = 0
    private var feelingCount = 0

    var averageFeeling: Double? {
        guard feelingCount > 0 else { return nil }
        return Double(feelingTotal) / Double(feelingCount)
    }

    mutating func include(_ record: WorkoutHistoryRecord) {
        if let lastUsed {
            self.lastUsed = max(lastUsed, record.completedAt)
        } else {
            lastUsed = record.completedAt
        }
        if let feeling = record.feeling {
            feelingTotal += feeling.sortValue
            feelingCount += 1
        }
    }
}

private extension WorkoutFeeling {
    var sortValue: Int {
        switch self {
        case .veryBad: 1
        case .bad: 2
        case .normal: 3
        case .prettyGood: 4
        case .excellent: 5
        }
    }
}

// Esta vista compone la pantalla inicial Workouts con el diseño de referencia ModiFiT.
struct WorkoutsView: View {
    @Environment(\.appColors) private var appColors

    @ObservedObject var viewModel: WorkoutsViewModel
    @ObservedObject var historyStore: WorkoutHistoryStore
    @ObservedObject var workoutLibrary: WorkoutLibraryStore
    @ObservedObject var workoutPreferences: WorkoutPreferencesStore
    @State private var searchText = ""
    @State private var sortCriterion = RoutineSortCriterion.created
    @State private var isSortDescending = true
    @State private var editingRoutine: Routine?
    @State private var deletingRoutine: Routine?
    @State private var workoutEditor: WorkoutEditorRequest?

    private var historyMetricsByRoutineID: [String: RoutineHistoryMetrics] {
        historyStore.records.reduce(into: [String: RoutineHistoryMetrics]()) { result, record in
            var metrics = result[record.routineID, default: RoutineHistoryMetrics()]
            metrics.include(record)
            result[record.routineID] = metrics
        }
    }

    private var visibleRoutines: [Routine] {
        let metrics = historyMetricsByRoutineID
        return workoutLibrary.standaloneRoutines
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { first, second in
                isOrderedBefore(first, second, metrics: metrics)
            }
    }

    private func isOrderedBefore(
        _ first: Routine,
        _ second: Routine,
        metrics: [String: RoutineHistoryMetrics]
    ) -> Bool {
        let firstMetrics = metrics[first.id] ?? RoutineHistoryMetrics()
        let secondMetrics = metrics[second.id] ?? RoutineHistoryMetrics()

        switch sortCriterion {
        case .created:
            if first.createdAt != second.createdAt {
                return isSortDescending ? first.createdAt > second.createdAt : first.createdAt < second.createdAt
            }
        case .duration:
            if first.estimatedMinutes != second.estimatedMinutes {
                return isSortDescending
                    ? first.estimatedMinutes > second.estimatedMinutes
                    : first.estimatedMinutes < second.estimatedMinutes
            }
        case .rating:
            switch (firstMetrics.averageFeeling, secondMetrics.averageFeeling) {
            case let (firstRating?, secondRating?) where firstRating != secondRating:
                return isSortDescending ? firstRating > secondRating : firstRating < secondRating
            case (_?, nil): return true
            case (nil, _?): return false
            default: break
            }
        case .lastUsed:
            switch (firstMetrics.lastUsed, secondMetrics.lastUsed) {
            case let (firstDate?, secondDate?) where firstDate != secondDate:
                return isSortDescending ? firstDate > secondDate : firstDate < secondDate
            case (_?, nil): return true
            case (nil, _?): return false
            default: break
            }
        }

        let nameOrder = first.name.localizedStandardCompare(second.name)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        return first.id < second.id
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 25) {
                    WorkoutHeaderView(onAdd: viewModel.presentAddWorkout)
                    FeaturedWorkoutCard(workout: workoutLibrary.featuredWorkout)
                    RoutinesSection(routines: visibleRoutines, searchText: searchText,
                                    sortCriterion: $sortCriterion, isSortDescending: $isSortDescending,
                                    onEdit: { editingRoutine = $0 }, onDelete: { deletingRoutine = $0 })
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .background(appColors.background.ignoresSafeArea())
            .navigationTitle("Workouts")
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search routines")
            .navigationDestination(for: Routine.self) { routine in
                TrainingScreen(routine: routine, historyStore: historyStore, workoutLibrary: workoutLibrary)
            }
            .navigationDestination(item: $viewModel.importedWorkout) { request in
                CreateWorkoutView(importedDraft: request.draft,
                                  onSaveImportedRoutines: workoutLibrary.saveRoutines,
                                  onBackToUpload: viewModel.requestReturnToScanner)
                    .navigationBarBackButtonHidden(true)
            }
            .fullScreenCover(item: $workoutEditor) { request in
                NavigationStack {
                    CreateWorkoutView(routine: request.routine,
                                      defaultSets: workoutPreferences.defaultSets,
                                      defaultRepetitions: workoutPreferences.defaultRepetitions,
                                      defaultRestSeconds: workoutPreferences.defaultRestSeconds) { name, exercises in
                        let routine = Routine(id: request.routine?.id ?? UUID().uuidString,
                                              name: name,
                                              symbol: request.routine?.symbol ?? Routine.randomGymSymbol(excluding: workoutLibrary.standaloneRoutines.last?.symbol),
                                              exercises: exercises.map { $0.makeFocusExercise() },
                                              createdAt: request.routine?.createdAt ?? Date(),
                                              activityCategory: request.routine?.activityCategory)
                        if request.routine == nil {
                            workoutLibrary.saveRoutine(routine)
                        } else {
                            workoutLibrary.updateRoutine(routine)
                        }
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
        .onChange(of: viewModel.importedWorkout?.id) { previous, current in
            guard previous != nil, current == nil else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                guard viewModel.importedWorkout == nil else { return }
                viewModel.reopenScannerIfRequested()
            }
        }
    }
}

private struct WorkoutEditorRequest: Identifiable, Hashable {
    let id = UUID()
    let routine: Routine?
}

// Este encabezado muestra el título y la acción de añadir rutina.
private struct WorkoutHeaderView: View {
    @Environment(\.appColors) private var appColors

    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("Workouts")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .tracking(-0.8)
                .foregroundStyle(appColors.text)
            Spacer(minLength: 0)
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(appColors.primary)
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
    @Environment(\.appColors) private var appColors

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
                Text("Latest Workout")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                if let workout {
                    let routine = workout.routine
                    Text(routine.name).font(.system(size: 18, weight: .medium, design: .rounded))
                    Label("\(routine.exerciseCount) exercises", systemImage: "dumbbell.fill")
                    Label("~ \(routine.estimatedMinutes) min (estimated)", systemImage: "timer")
                } else {
                    Text("Use + to add a routine.")
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
        .background(appColors.primary, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: appColors.secondary.opacity(0.16), radius: 12, x: 0, y: 7)
    }
}

// Esta sección muestra las rutinas creadas y sus controles de ordenación.
private struct RoutinesSection: View {
    @Environment(\.appColors) private var appColors
    @ScaledMetric(relativeTo: .largeTitle) private var emptyStateIconSize: CGFloat = 56

    let routines: [Routine]
    let searchText: String
    @Binding var sortCriterion: RoutineSortCriterion
    @Binding var isSortDescending: Bool
    let onEdit: (Routine) -> Void
    let onDelete: (Routine) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Routines")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .tracking(-0.45)
                .foregroundStyle(appColors.text)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RoutineSortCriterion.allCases) { criterion in
                        sortChip(for: criterion)
                    }
                }
                .padding(.vertical, 2)
                .fixedSize(horizontal: true, vertical: false)
            }

            HStack {
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        isSortDescending.toggle()
                    }
                } label: {
                    Image(systemName: isSortDescending ? "arrow.down" : "arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(appColors.primary)
                        .frame(width: 44, height: 44)
                        .background(appColors.surface, in: Circle())
                        .overlay(Circle().stroke(appColors.border, lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSortDescending ? "Descending order" : "Ascending order")
                .accessibilityHint("Switch to \(isSortDescending ? "ascending" : "descending") order")
            }

            if routines.isEmpty {
                if !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: emptyStateIconSize, weight: .regular))
                            .foregroundStyle(appColors.primary)
                        Text("No workouts created yet")
                            .font(.system(.title3, design: .rounded, weight: .light))
                            .foregroundStyle(appColors.text)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 30)
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(routines) { routine in
                        RoutineRowView(routine: routine, onEdit: { onEdit(routine) }, onDelete: { onDelete(routine) })
                    }
                }
            }
        }
    }

    private func sortChip(for criterion: RoutineSortCriterion) -> some View {
        let isSelected = sortCriterion == criterion

        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                sortCriterion = criterion
            }
        } label: {
            Text(criterion.title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? appColors.surface : appColors.text)
                .padding(.horizontal, 15)
                .frame(height: 40)
                .background(isSelected ? appColors.primary : appColors.surface, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : appColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Sort routines by \(criterion.title.lowercased())")
    }
}

// Esta fila separa el símbolo, la descripción de la rutina y su indicador de navegación.
private struct RoutineRowView: View {
    @Environment(\.appColors) private var appColors

    let routine: Routine
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            NavigationLink(value: routine) {
                HStack(spacing: 16) {
                    Image(systemName: routine.symbol)
                        .font(.system(size: 29, weight: .medium))
                        .foregroundStyle(appColors.primary)
                        .frame(width: 66, height: 66)
                        .background(appColors.accent.opacity(0.63), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(routine.name).font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(appColors.text)
                        Text("\(routine.exerciseCount) exercises · ~ \(routine.estimatedMinutes) min")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(appColors.secondaryText)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityHint("Choose exercises for this routine")

            Menu {
                Button("Edit", systemImage: "pencil", action: onEdit)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(appColors.primary)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(appColors.primary.opacity(0.14))
                            .frame(width: 36, height: 36)
                    }
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Actions for \(routine.name)")
            .accessibilityHint("Edit or delete this routine")
            .zIndex(1)
        }
        .padding(.leading, 17).padding(.trailing, 12).padding(.vertical, 17)
        .frame(maxWidth: .infinity, minHeight: 100)
        .appCard()
    }
}
import SwiftUI

// Esta hoja presenta las dos opciones de incorporación de rutinas indicadas en el diseño.
struct AddWorkoutSheet: View {
    @Environment(\.appColors) private var appColors

    @Environment(\.dismiss) private var dismiss
    @State private var showingScanner = false
    @State private var didOpenInitialScanner = false
    let startAtScanner: Bool
    let onImportReady: (WorkoutImportDraft) -> Void
    let onCreateManually: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 13) {
                Text("Choose how to add a routine.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(appColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)

                FloatingMascotView().frame(height: 145).padding(.vertical, 2)

                Button { showingScanner = true } label: {
                    AddWorkoutOption(title: "Scan Routine", subtitle: "Take a photo or choose a file from your device.", symbol: "viewfinder")
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
            .background(appColors.background.ignoresSafeArea())
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingScanner) {
                WorkoutScannerView { draft in
                    onImportReady(draft)
                    dismiss()
                }
            }
        }
        .task {
            guard startAtScanner, !didOpenInitialScanner else { return }
            didOpenInitialScanner = true
            showingScanner = true
        }
    }
}

// Esta fila representa una acción de la hoja con una superficie táctil amplia.
private struct AddWorkoutOption: View {
    @Environment(\.appColors) private var appColors

    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: symbol).font(.system(size: 22, weight: .medium)).foregroundStyle(appColors.primary)
                .frame(width: 52, height: 52).background(appColors.accent.opacity(0.62), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(appColors.text)
                Text(subtitle).font(.system(size: 13, weight: .regular, design: .rounded)).foregroundStyle(appColors.secondaryText).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(appColors.secondary)
        }
        .padding(15).frame(maxWidth: .infinity, minHeight: 84).appCard()
    }
}

// Esta pantalla temporal confirma la opción elegida y deja preparada su ruta de navegación.
private struct AddWorkoutDestination: View {
    @Environment(\.appColors) private var appColors

    let title: String
    let symbol: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 38)).foregroundStyle(appColors.primary)
            Text(title).font(.title2.bold()).foregroundStyle(appColors.text)
            Text("This feature will be available in a future update.")
                .font(.subheadline).foregroundStyle(appColors.secondaryText).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appColors.background.ignoresSafeArea())
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}
