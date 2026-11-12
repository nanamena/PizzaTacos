import SwiftUI

enum WorkoutTheme {
    static let navigationTint = Color(uiColor: UIColor { traits in
        if traits.accessibilityContrast == .high {
            return traits.userInterfaceStyle == .dark
                ? UIColor(red: 1, green: 0.55, blue: 0.68, alpha: 1)
                : UIColor(red: 0.70, green: 0.07, blue: 0.27, alpha: 1)
        }
        return traits.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 0.40, blue: 0.57, alpha: 1)
            : UIColor(red: 0.88, green: 0.16, blue: 0.36, alpha: 1)
    })
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 0.40, blue: 0.57, alpha: 1)
            : UIColor(red: 0.77, green: 0.10, blue: 0.32, alpha: 1)
    })
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.075, green: 0.065, blue: 0.08, alpha: 1)
            : UIColor(red: 0.995, green: 0.965, blue: 0.978, alpha: 1)
    })
}

enum WorkoutsTab: Hashable {
    case workouts, progress, settings
}

struct WorkoutsRootView: View {
    @State private var store: WorkoutStore
    @State private var selectedTab: WorkoutsTab
    @AppStorage("workouts.appearance") private var appearance = "system"

    init(store: WorkoutStore? = nil, initialTab: WorkoutsTab = .workouts) {
        _store = State(initialValue: store ?? WorkoutStore())
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Workouts", systemImage: "dumbbell.fill", value: .workouts) {
                NavigationStack { WorkoutsView(store: store) }
            }
            Tab("Progress", systemImage: "chart.bar.fill", value: .progress) {
                NavigationStack {
                    WorkoutProgressView()
                }
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    Form {
                        Picker("Appearance", selection: $appearance) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                    }
                    .navigationTitle("Settings")
                }
            }
        }
        // Keep all three destinations visible while scrolling.
        // iOS owns the glass, selection shape, label font and bottom safe area.
        .tabBarMinimizeBehavior(.never)
        .tint(WorkoutTheme.navigationTint)
        .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
    }
}

private enum WorkoutFilter: String, CaseIterable, Identifiable {
    case all = "All", favorites = "Favorites"
    var id: String { rawValue }
}

private enum WorkoutSort: String, CaseIterable, Identifiable {
    case date = "Date", name = "Name", duration = "Duration"
    var id: String { rawValue }
}

// Step 2: let iOS draw and animate the segmented control, including its
// selected background. No custom capsule overlays or global appearance changes.
private struct WorkoutFilterControl: View {
    @Binding var selection: WorkoutFilter
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // Segments cannot grow into multiple lines reliably.
                // A native menu preserves legibility at accessibility text sizes.
                Picker("Show workouts", selection: $selection) {
                    options
                }
                .pickerStyle(.menu)
                .font(.body)
            } else {
                Picker("Show workouts", selection: $selection) {
                    options
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityIdentifier("workouts.filter")
    }

    private var options: some View {
        ForEach(WorkoutFilter.allCases) { filter in
            Text(filter.rawValue).tag(filter)
        }
    }
}

private struct WorkoutFilterPreview: View {
    @State private var selection = WorkoutFilter.all

    var body: some View {
        VStack(spacing: 20) {
            WorkoutsHeader(onAdd: {})
            WorkoutFilterControl(selection: $selection)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(WorkoutsScreenBackground())
    }
}

#Preview("Step 2 — Header and filter", traits: .sizeThatFitsLayout) {
    WorkoutFilterPreview().preferredColorScheme(.light)
}

#Preview("Step 2 — Accessible filter", traits: .sizeThatFitsLayout) {
    WorkoutFilterPreview()
        .environment(\.dynamicTypeSize, .accessibility2)
        .preferredColorScheme(.dark)
}

// Step 3: a content row, not a List section header. This keeps its edges
// aligned with the title and filter instead of inheriting section-header insets.
private struct WorkoutCollectionControls: View {
    let count: Int
    @Binding var sort: WorkoutSort
    @Binding var ascending: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            Text("\(count) \(count == 1 ? "workout" : "workouts")")
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("workouts.count")
            Menu {
                Picker("Sort by", selection: $sort) {
                    ForEach(WorkoutSort.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Order", selection: $ascending) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.body.weight(.regular))
                    Text(sort.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(contrast == .increased || colorScheme == .dark
                    ? WorkoutTheme.accent : Color(red: 0.88, green: 0.16, blue: 0.36))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sort by \(sort.rawValue), \(ascending ? "ascending" : "descending")")
            .accessibilityIdentifier("workouts.sort")
        }
        .font(.body)
        .textCase(nil)
        .frame(maxWidth: .infinity)
    }
}

private struct WorkoutControlsPreview: View {
    @State private var filter = WorkoutFilter.all
    @State private var sort = WorkoutSort.date
    @State private var ascending = false

    var body: some View {
        VStack(spacing: 20) {
            WorkoutsHeader(onAdd: {})
            WorkoutFilterControl(selection: $filter)
            WorkoutCollectionControls(count: filter == .all ? 5 : 2,
                                      sort: $sort, ascending: $ascending)
                .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(WorkoutsScreenBackground())
    }
}

#Preview("Step 3 — Count and sorting", traits: .sizeThatFitsLayout) {
    WorkoutControlsPreview().preferredColorScheme(.light)
}

#Preview("Step 3 — Accessible controls", traits: .sizeThatFitsLayout) {
    WorkoutControlsPreview()
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility2)
}

struct WorkoutsView: View {
    @Bindable var store: WorkoutStore
    @State private var filter = WorkoutFilter.all
    @State private var sort = WorkoutSort.date
    @State private var ascending = false
    @State private var showingAdd = false
    @State private var pendingDeletion: Workout?

    private var visibleWorkouts: [Workout] {
        store.workouts.filter { filter == .all || $0.isFavorite }.sorted { a, b in
            let comparison: ComparisonResult
            switch sort {
            case .date: comparison = a.createdAt.compare(b.createdAt)
            case .name: comparison = a.name.localizedStandardCompare(b.name)
            case .duration:
                comparison = a.estimatedMinutes == b.estimatedMinutes ? .orderedSame
                    : a.estimatedMinutes < b.estimatedMinutes ? .orderedAscending : .orderedDescending
            }
            if comparison == .orderedSame { return a.id.uuidString < b.id.uuidString }
            return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 20) {
                    WorkoutsHeader { showingAdd = true }
                    WorkoutFilterControl(selection: $filter)
                    WorkoutCollectionControls(count: visibleWorkouts.count, sort: $sort, ascending: $ascending)
                        .padding(.top, 8)
                }
                .padding(.top, 24)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                if visibleWorkouts.isEmpty {
                    ContentUnavailableView {
                        Label(filter == .favorites ? "No favorites yet" : "No workouts yet",
                              systemImage: filter == .favorites ? "heart" : "dumbbell")
                    } description: {
                        Text(filter == .favorites ? "Add a workout to favorites from its details or by swiping a row." : "Tap + to create your first workout.")
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(visibleWorkouts) { workout in
                        NavigationLink {
                            WorkoutDetailView(store: store, workoutID: workout.id)
                        } label: { WorkoutRow(workout: workout) }
                        .listRowInsets(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
                        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        .swipeActions(edge: .leading) {
                            Button { store.toggleFavorite(workout.id) } label: {
                                Label(workout.isFavorite ? "Unfavorite" : "Favorite",
                                      systemImage: workout.isFavorite ? "heart.slash" : "heart")
                            }.tint(WorkoutTheme.accent)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { pendingDeletion = workout } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(workout.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                   systemImage: workout.isFavorite ? "heart.slash" : "heart") {
                                store.toggleFavorite(workout.id)
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                pendingDeletion = workout
                            }
                        }
                    }
                }
            }

            // Mascot insertion point: add a clear-background Section here.
            // Do not use a fixed-height spacer: keep this screen scrollable at large text sizes.
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(12)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .contentMargins(.bottom, 24, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(WorkoutsScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAdd) {
            WorkoutEditor { store.save($0) }
        }
        .confirmationDialog("Delete workout?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("Delete workout", role: .destructive) {
                if let workout = pendingDeletion { store.delete(workout.id) }
                pendingDeletion = nil
            }
        } message: {
            Text("This removes \(pendingDeletion?.name ?? "the workout") from your collection.")
        }
        .safeAreaInset(edge: .bottom) {
            if let error = store.storageError {
                Text(error).font(.footnote).padding().background(.regularMaterial)
            }
        }
    }
}

// Step 1: isolated header. All measurements are in points, not screenshot pixels.
// The reference is approximately 393 points wide: title ~36 pt, plus circle 44 pt.
struct WorkoutsHeader: View {
    var onAdd: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 36
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("Workouts")
                .font(.system(size: titleSize, weight: .bold, design: .default))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(contrast == .increased
                        ? WorkoutTheme.accent : Color(red: 1, green: 0.22, blue: 0.43))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .accessibilityLabel("Add workout")
        }
    }
}

struct WorkoutsScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                WorkoutTheme.background
            } else {
                LinearGradient(
                    colors: [Color(red: 1, green: 0.972, blue: 0.983),
                             Color(red: 0.993, green: 0.956, blue: 0.978)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

#Preview("Step 1 — Header only", traits: .sizeThatFitsLayout) {
    WorkoutsHeader(onAdd: {})
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(WorkoutsScreenBackground())
        .environment(\.colorScheme, .light)
}

private struct WorkoutRow: View {
    let workout: Workout
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .subheadline) private var metadataSize = 14

    private var pink: Color {
        contrast == .increased || colorScheme == .dark
            ? WorkoutTheme.accent : Color(red: 1, green: 0.22, blue: 0.43)
    }

    private var iconBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.25, green: 0.12, blue: 0.19)
            : Color(red: 1, green: 0.88, blue: 0.93)
    }

    var body: some View {
        HStack(spacing: 16) {
            if !typeSize.isAccessibilitySize {
                Image(systemName: workout.symbol)
                    .font(.system(size: 27, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.82))
                    .frame(width: 48, height: 48)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) {
                        exerciseCount
                        Text("·").foregroundStyle(.secondary)
                        duration
                    }
                    VStack(alignment: .leading, spacing: 4) { exerciseCount; duration }
                }
                .font(.system(size: metadataSize, weight: .regular, design: .default))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if workout.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(pink)
                    .frame(width: 22)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 48)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(workout.name), \(workout.exerciseCount) exercises, approximately \(workout.estimatedMinutes) minutes\(workout.isFavorite ? ", favorite" : "")")
    }

    private var exerciseCount: some View {
        Text("\(workout.exerciseCount) \(workout.exerciseCount == 1 ? "exercise" : "exercises")")
            .foregroundStyle(.secondary)
    }

    private var duration: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock").foregroundStyle(pink)
            Text("≈ \(workout.estimatedMinutes) min").foregroundStyle(.secondary)
        }
    }
}

private struct WorkoutRowsPreview: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Workout.samples) { workout in
                        NavigationLink {
                            Text(workout.name).navigationTitle(workout.name)
                        } label: {
                            WorkoutRow(workout: workout)
                        }
                        .listRowInsets(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
                        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(WorkoutsScreenBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview("Step 4 — Workout rows") {
    WorkoutRowsPreview().preferredColorScheme(.light)
}

#Preview("Step 4 — Accessible rows") {
    WorkoutRowsPreview()
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility2)
}

private struct WorkoutDetailView: View {
    @Bindable var store: WorkoutStore
    let workoutID: UUID
    @State private var showingEdit = false
    private var workout: Workout? { store.workouts.first { $0.id == workoutID } }

    var body: some View {
        Group {
            if let workout {
                Form {
                    Section {
                        LabeledContent("Exercises", value: "\(workout.exerciseCount)")
                        LabeledContent { Text("≈ \(workout.estimatedMinutes) min") } label: {
                            Label("Estimated duration", systemImage: "clock")
                        }
                        Toggle("Favorite", isOn: Binding(
                            get: { self.workout?.isFavorite ?? false },
                            set: { newValue in
                                if newValue != self.workout?.isFavorite { store.toggleFavorite(workoutID) }
                            }
                        ))
                    } footer: {
                        Text("Demo summary. Connect your exercises and duration calculation here.")
                    }
                }
                .navigationTitle(workout.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") { showingEdit = true }
                    }
                }
                .sheet(isPresented: $showingEdit) {
                    WorkoutEditor(workout: workout) { store.save($0) }
                }
            } else {
                ContentUnavailableView("Workout not available", systemImage: "dumbbell")
            }
        }
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct WorkoutEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Workout
    private let isNew: Bool
    let onSave: (Workout) -> Void

    init(workout: Workout? = nil, onSave: @escaping (Workout) -> Void) {
        _draft = State(initialValue: workout ?? Workout(name: "", symbol: "dumbbell", exerciseCount: 6, estimatedMinutes: 45))
        isNew = workout == nil
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    TextField("Name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                    Picker("Icon", selection: $draft.symbol) {
                        Label("Strength", systemImage: "dumbbell").tag("dumbbell")
                        Label("Functional", systemImage: "figure.strengthtraining.functional").tag("figure.strengthtraining.functional")
                        Label("Mobility", systemImage: "figure.cooldown").tag("figure.cooldown")
                        Label("Full body", systemImage: "figure.run").tag("figure.run")
                        Label("HIIT", systemImage: "bolt").tag("bolt")
                    }
                    Toggle("Favorite", isOn: $draft.isFavorite)
                }
                Section {
                    Stepper("\(draft.exerciseCount) exercises", value: $draft.exerciseCount, in: 1...100)
                    Stepper("≈ \(draft.estimatedMinutes) min", value: $draft.estimatedMinutes, in: 1...600)
                } header: { Text("Demo values") } footer: {
                    Text("These values populate the collection preview. In your app, derive them from the workout exercises, sets and rests.")
                }
            }
            .navigationTitle(isNew ? "New Workout" : "Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview("Light") {
    WorkoutsRootView(store: WorkoutStore(defaults: nil))
        .preferredColorScheme(.light)
}

// Full-screen previews include the real system tab bar; component previews above
// intentionally omit it. In-memory storage keeps sample edits out of real data.
#Preview("Step 5 — Full screen") {
    WorkoutsRootView(store: WorkoutStore(defaults: nil))
}

#Preview("Step 5 — Full screen / Large Text") {
    WorkoutsRootView(store: WorkoutStore(defaults: nil))
        .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Dark / Large Text") {
    WorkoutsRootView(store: WorkoutStore(defaults: nil))
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility2)
}
