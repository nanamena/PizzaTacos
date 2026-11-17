import SwiftUI
import UIKit

private enum RitmoviaStyle {
    static let red = Color(hex: 0xC65F32)
    static let orange = Color(hex: 0xC65F32)
    static let brown = Color(hex: 0xA94725)
    static let warmWhite = adaptive(light: 0xFFF8F0, dark: 0x241A16)
    static let cream = adaptive(light: 0xF4D5C2, dark: 0x493026)
    static let card = adaptive(light: 0xFFFFFF, dark: 0x352720)
    static let ink = adaptive(light: 0x38251F, dark: 0xFFF8F0)
    static let secondary = adaptive(light: 0x80685E, dark: 0xD0B9AB)
    static let border = adaptive(light: 0xEBD8CB, dark: 0x5E453A)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 0xff) / 255,
                           green: CGFloat((value >> 8) & 0xff) / 255,
                           blue: CGFloat(value & 0xff) / 255, alpha: 1)
        })
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255, opacity: 1)
    }
}

private enum MainTab: String, CaseIterable {
    case workouts = "Workouts"
    case progress = "Progress"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .workouts: "dumbbell"
        case .progress: "chart.bar"
        case .settings: "gearshape"
        }
    }
}

private struct SavedExercise: Codable, Identifiable {
    var id = UUID()
    var name = ""
    var sets = 3
    var reps = 10
    var restSeconds = 60
}

private struct SavedPlan: Codable, Identifiable {
    var id = UUID()
    var name: String
    var duration: String
    var createdAt = Date()
    var exercises: [SavedExercise]
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .workouts
    @State private var showingAddWorkout = false
    @State private var availableMinutes = 30.0
    @State private var showingWorkoutNotice = false
    @AppStorage("ritmovia.savedPlans") private var savedPlansData = "[]"
    @AppStorage("ritmovia.theme") private var theme = "system"

    private var savedPlans: [SavedPlan] {
        (try? JSONDecoder().decode([SavedPlan].self, from: Data(savedPlansData.utf8))) ?? []
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { workoutsScreen }
                .tabItem { Label(MainTab.workouts.rawValue, systemImage: MainTab.workouts.symbol) }
                .tag(MainTab.workouts)
            NavigationStack { ProgressScreen(planCount: savedPlans.count) }
                .tabItem { Label(MainTab.progress.rawValue, systemImage: MainTab.progress.symbol) }
                .tag(MainTab.progress)
            NavigationStack { SettingsScreen(theme: $theme) }
                .tabItem { Label(MainTab.settings.rawValue, systemImage: MainTab.settings.symbol) }
                .tag(MainTab.settings)
        }
        .tint(RitmoviaStyle.red)
        .sheet(isPresented: $showingAddWorkout) {
            AddWorkoutSheet { plan in
                var plans = savedPlans
                plans.append(plan)
                if let data = try? JSONEncoder().encode(plans), let value = String(data: data, encoding: .utf8) {
                    savedPlansData = value
                }
            }
        }
        .preferredColorScheme(theme == "system" ? nil : (theme == "dark" ? .dark : .light))
    }

    private var workoutsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                    Text("Hello!").font(.subheadline).foregroundStyle(RitmoviaStyle.secondary)
                        Text("Workouts").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(RitmoviaStyle.ink)
                    }
                    Spacer()
                    Button { showingAddWorkout = true } label: {
                        Image(systemName: "plus").font(.title2.weight(.semibold)).foregroundStyle(RitmoviaStyle.red)
                            .frame(width: 48, height: 48).background(.white, in: Circle())
                    }
                    .accessibilityLabel("Add workout")
                }

                if let plan = savedPlans.last {
                    ZStack(alignment: .trailing) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TODAY'S WORKOUT").font(.caption.bold()).tracking(1).opacity(0.85)
                            Text(plan.name).font(.title2.bold())
                            Text("\(plan.exercises.count) exercises").font(.subheadline)
                            Text("~28 min (estimated)").font(.caption)
                        }
                        Image("ModiFITMascot")
                            .resizable().scaledToFit().frame(width: 102, height: 118)
                            .padding(.trailing, 4).accessibilityLabel("ModiFIT fitness mascot")
                    }
                    .foregroundStyle(.white).padding(.leading, 20).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
                    .background(RitmoviaStyle.orange, in: RoundedRectangle(cornerRadius: 24))
                } else {
                    ZStack(alignment: .trailing) {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("Today's Workout").font(.headline.bold())
                            Text("Add a plan to organize today's session.").font(.subheadline).foregroundStyle(.white.opacity(0.9))
                            Button { showingAddWorkout = true } label: {
                                Label("Add Workout", systemImage: "plus.circle.fill").font(.subheadline.bold())
                            }.tint(.white)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image("ModiFITMascot").resizable().scaledToFit().frame(width: 100, height: 120)
                            .accessibilityLabel("ModiFIT fitness mascot")
                    }
                    .foregroundStyle(.white).padding(.horizontal, 18).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 142)
                    .background(RitmoviaStyle.orange, in: RoundedRectangle(cornerRadius: 24))
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("How much time do you have today?").font(.headline).foregroundStyle(RitmoviaStyle.ink)
                    Text("Choose your available training time.").font(.subheadline).foregroundStyle(RitmoviaStyle.secondary)
                    HStack(spacing: 18) {
                        timeButton("minus", delta: -5)
                        Text("\(Int(availableMinutes)) min")
                            .font(.system(size: 25, weight: .bold, design: .rounded)).monospacedDigit()
                            .frame(maxWidth: .infinity)
                        timeButton("plus", delta: 5)
                    }
                    Slider(value: $availableMinutes, in: 10...120, step: 5).tint(RitmoviaStyle.orange)
                    Button { showingWorkoutNotice = true } label: {
                        Label("Start Workout", systemImage: "play.fill")
                            .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(RitmoviaStyle.red, in: Capsule())
                    }
                    .accessibilityHint("Add a workout plan before starting a session")
                }
                .padding(18).cardSurface()
                .alert("Workout timer", isPresented: $showingWorkoutNotice) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(savedPlans.isEmpty ? "Add a workout plan before starting a session." : "The workout timer will be added in the Focus Workout phase.")
                }

                HStack {
                    Text("Today's Exercises").font(.title3.bold()).foregroundStyle(RitmoviaStyle.ink)
                    Spacer()
                }
                if let plan = savedPlans.last, !plan.exercises.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(plan.exercises) { exercise in
                            HStack(spacing: 12) {
                                Image(systemName: "dumbbell.fill").foregroundStyle(RitmoviaStyle.orange)
                                    .frame(width: 40, height: 40).background(RitmoviaStyle.cream, in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(exercise.name).font(.headline).foregroundStyle(RitmoviaStyle.ink)
                                    Text("\(exercise.sets) sets × \(exercise.reps) reps · \(exercise.restSeconds)s rest")
                                        .font(.caption).foregroundStyle(RitmoviaStyle.secondary)
                                }
                                Spacer()
                            }.padding(12).cardSurface()
                        }
                    }
                } else {
                    EmptyCard(symbol: "list.bullet", text: "Exercises from your saved plan will show here.")
                }
            }
            .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 20)
        }
        .background(RitmoviaStyle.warmWhite.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func timeButton(_ symbol: String, delta: Double) -> some View {
        Button {
            availableMinutes = min(120, max(10, availableMinutes + delta))
        } label: {
            Image(systemName: symbol).font(.headline.weight(.bold)).foregroundStyle(RitmoviaStyle.red)
                .frame(width: 42, height: 42).background(RitmoviaStyle.cream, in: Circle())
        }.accessibilityLabel(delta > 0 ? "Add 5 minutes" : "Remove 5 minutes")
    }

    private func simpleScreen(title: String, subtitle: String, symbol: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(RitmoviaStyle.ink)
            Text(subtitle).font(.subheadline).foregroundStyle(RitmoviaStyle.secondary)
            Spacer()
            EmptyCard(symbol: symbol, text: message)
            Spacer()
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(RitmoviaStyle.warmWhite.ignoresSafeArea())
    }
}

private struct EmptyCard: View {
    let symbol: String
    let text: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(RitmoviaStyle.orange)
                .frame(width: 42, height: 42).background(RitmoviaStyle.cream, in: Circle())
            Text(text).font(.subheadline).foregroundStyle(RitmoviaStyle.secondary)
            Spacer(minLength: 0)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }
}

private struct AddWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (SavedPlan) -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Choose how to add your training plan.").font(.subheadline).foregroundStyle(RitmoviaStyle.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image("ModiFITMascot").resizable().scaledToFit().frame(height: 150)
                    .accessibilityLabel("ModiFIT fitness mascot")
                NavigationLink { ScanPlaceholderScreen() } label: {
                    optionRow("Scan Workout Plan", detail: "Take a photo, choose a photo or browse files.", symbol: "viewfinder")
                }
                NavigationLink { CreateWorkoutScreen(onSave: onSave) } label: {
                    optionRow("Create Manually", detail: "Add exercises, sets, reps and rest time.", symbol: "pencil")
                }
                Spacer()
            }
            .padding(20).background(RitmoviaStyle.warmWhite.ignoresSafeArea())
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.tint(RitmoviaStyle.red) } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func optionRow(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(RitmoviaStyle.red).frame(width: 48, height: 48).background(RitmoviaStyle.cream, in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(RitmoviaStyle.ink)
                Text(detail).font(.caption).foregroundStyle(RitmoviaStyle.secondary).multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(RitmoviaStyle.secondary)
        }.padding(16).cardSurface()
    }
}

private struct ScanPlaceholderScreen: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.viewfinder").font(.system(size: 42)).foregroundStyle(RitmoviaStyle.orange)
            Text("Scan Workout Plan").font(.title2.bold()).foregroundStyle(RitmoviaStyle.ink)
            Text("Photo, Photos and Files import will be added in the scanning phase.").font(.body).foregroundStyle(RitmoviaStyle.secondary).multilineTextAlignment(.center)
        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity).background(RitmoviaStyle.warmWhite)
            .navigationTitle("Scan Workout Plan").navigationBarTitleDisplayMode(.inline)
    }
}

private struct CreateWorkoutScreen: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (SavedPlan) -> Void
    @State private var workoutName = ""
    @State private var planDuration = "1 month"
    @State private var exercises = [SavedExercise()]
    @State private var showingValidation = false

    private let durations = ["2 weeks", "1 month", "3 months", "6 months", "Ongoing"]

    var body: some View {
        Form {
            Section("Workout Name") {
                TextField("e.g. Upper Body, Push Day", text: $workoutName)
                Picker("Plan duration", selection: $planDuration) {
                    ForEach(durations, id: \.self) { Text($0) }
                }
            }
            ForEach($exercises) { $exercise in
                Section {
                    TextField("e.g. Bench Press", text: $exercise.name)
                    Stepper("Sets   \(exercise.sets)", value: $exercise.sets, in: 1...20)
                    Stepper("Reps   \(exercise.reps)", value: $exercise.reps, in: 1...100)
                    Stepper("Rest   \(exercise.restSeconds) sec", value: $exercise.restSeconds, in: 0...600, step: 15)
                    if exercises.count > 1 {
                        Button(role: .destructive) {
                            exercises.removeAll { $0.id == exercise.id }
                        } label: { Label("Remove Exercise", systemImage: "trash") }
                    }
                } header: { Text("Exercise \(exercises.firstIndex(where: { $0.id == exercise.id }).map { $0 + 1 } ?? 1)") }
            }
            Section {
                Button { exercises.append(SavedExercise()) } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill").font(.headline)
                }
            }
            Section {
                Text("\(exercises.reduce(0) { $0 + $1.sets }) total sets · Estimated time includes rest periods.")
                    .font(.footnote).foregroundStyle(RitmoviaStyle.secondary)
                Button("Done") {
                    let validExercises = exercises.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                    guard !workoutName.trimmingCharacters(in: .whitespaces).isEmpty, !validExercises.isEmpty else {
                        showingValidation = true
                        return
                    }
                    onSave(SavedPlan(name: workoutName.trimmingCharacters(in: .whitespaces), duration: planDuration, exercises: validExercises))
                    dismiss()
                }
                    .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 8)
                    .listRowBackground(RitmoviaStyle.red)
            }
        }
        .alert("Add a workout name and at least one exercise.", isPresented: $showingValidation) {
            Button("OK", role: .cancel) { }
        }
        .scrollContentBackground(.hidden).background(RitmoviaStyle.warmWhite)
        .navigationTitle("Create Workout").navigationBarTitleDisplayMode(.inline)
        .tint(RitmoviaStyle.red)
    }
}

private struct ProgressScreen: View {
    @State private var period = "Week"
    private let periods = ["Week", "Month", "Year"]
    let planCount: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Progress").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(RitmoviaStyle.ink)
                    Text("Your training at a glance.").font(.subheadline).foregroundStyle(RitmoviaStyle.secondary)
                }
                Picker("Period", selection: $period) {
                    ForEach(periods, id: \.self) { Text($0) }
                }.pickerStyle(.segmented)

                HStack(spacing: 12) {
                    statisticCard("Training days", value: "—", symbol: "calendar")
                    statisticCard("Avg. time", value: "—", symbol: "clock")
                }
                HStack(spacing: 12) {
                    statisticCard("Workout plans", value: "\(planCount)", symbol: "dumbbell")
                    statisticCard("Total time", value: "—", symbol: "timer")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Training Consistency").font(.headline).foregroundStyle(RitmoviaStyle.ink)
                    EmptyCard(symbol: "chart.bar", text: "Complete a workout to see your consistency for this \(period.lowercased()).")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("How You Felt").font(.headline).foregroundStyle(RitmoviaStyle.ink)
                    EmptyCard(symbol: "face.smiling", text: "Your post-workout feedback will appear here.")
                }
            }.padding(18)
        }
        .background(RitmoviaStyle.warmWhite.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func statisticCard(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(RitmoviaStyle.red)
            Text(value).font(.title2.bold()).foregroundStyle(RitmoviaStyle.ink)
            Text(title).font(.caption).foregroundStyle(RitmoviaStyle.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).cardSurface()
    }
}

private struct SettingsScreen: View {
    @Binding var theme: String
    @AppStorage("ritmovia.defaultRest") private var defaultRest = 60
    @AppStorage("ritmovia.defaultSets") private var defaultSets = 3
    @AppStorage("ritmovia.autoNext") private var autoNext = false
    @AppStorage("ritmovia.voiceCues") private var voiceCues = true

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image("ModiFITMascot").resizable().scaledToFit().frame(width: 52, height: 52)
                        .accessibilityLabel("ModiFIT mascot profile image")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Profile").font(.headline)
                        Text("View and edit your profile").font(.caption).foregroundStyle(RitmoviaStyle.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(RitmoviaStyle.secondary)
                }
                Text("Profile editing will be available in a future update.").font(.footnote).foregroundStyle(RitmoviaStyle.secondary)
            } header: { Text("Account") }
            Section("Appearance") {
                Picker("App Theme", selection: $theme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
            }
            Section("Workout Preferences") {
                Stepper("Default Rest: \(defaultRest) sec", value: $defaultRest, in: 0...300, step: 15)
                Stepper("Default Sets: \(defaultSets)", value: $defaultSets, in: 1...10)
                Toggle("Auto-Next Exercise", isOn: $autoNext)
                Toggle("Voice Workout Cues", isOn: $voiceCues)
            }
            Section("Permissions & Integrations") {
                Label("Apple Health", systemImage: "heart.text.square")
                Text("Health access can be connected when workout tracking is added.").font(.footnote).foregroundStyle(RitmoviaStyle.secondary)
                Label("Apple Watch", systemImage: "applewatch")
                Text("Watch companion support is planned for a future update.").font(.footnote).foregroundStyle(RitmoviaStyle.secondary)
            }
            Section("About") {
                HStack(spacing: 12) {
                    Image("ModiFITLogo").resizable().scaledToFit().frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("ModiFIT").font(.headline)
                }
                LabeledContent("App", value: "ModiFIT")
                LabeledContent("Version", value: "1.0")
            }
        }
        .scrollContentBackground(.hidden)
        .background(RitmoviaStyle.warmWhite)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .tint(RitmoviaStyle.red)
    }
}

private extension View {
    func cardSurface() -> some View {
        self.background(RitmoviaStyle.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(RitmoviaStyle.border.opacity(0.65), lineWidth: 0.7))
    }
}

#Preview {
    ContentView()
}
