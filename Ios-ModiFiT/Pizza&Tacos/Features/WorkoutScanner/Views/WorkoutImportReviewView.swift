import SwiftUI

struct WorkoutImportReviewView: View {
    @Binding var draft: WorkoutImportDraft
    let activePlanName: String?
    let onActivate: (String, [Routine]) -> Void

    var body: some View {
        Form {
            Section {
                TextField("Plan name", text: $draft.name)
            } footer: {
                if draft.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("No text could be read. Add the exercises below or go back and choose a clearer copy.")
                } else if draft.days.allSatisfy({ $0.exercises.isEmpty }) {
                    Text("The text was read, but no exercise rows were recognized. Use Recognized Text below to fill in the days.")
                } else {
                    Text("Check each day against your original. When rest is missing, the draft uses 60 seconds.")
                }
            }

            ForEach($draft.days) { $day in
                Section {
                    TextField("Day name", text: $day.name)
                    ForEach($day.exercises) { $exercise in
                        ExerciseFields(exercise: $exercise)
                    }
                    .onDelete { day.exercises.remove(atOffsets: $0) }
                    Button("Add Exercise", systemImage: "plus") { day.exercises.append(.init()) }
                    if draft.days.count > 1 {
                        Button("Remove Day", role: .destructive) { removeDay(day.id) }
                    }
                } header: {
                    Text(verbatim: day.name)
                }
            }
            Button("Add Day", systemImage: "plus", action: addDay)

            if !draft.recognizedText.isEmpty {
                Section {
                    DisclosureGroup("Recognized Text") {
                        Text(verbatim: draft.recognizedText.replacingOccurrences(of: "\t", with: "   "))
                            .font(.footnote)
                            .textSelection(.enabled)
                    }
                }
            }

            Section {
                Button(activePlanName == nil ? "Activate Plan" : "Replace Active Plan", action: activate)
                    .disabled(!draft.canActivate)
            } footer: {
                if let activePlanName {
                    Text("This replaces \(activePlanName) and starts the new plan at its first day.")
                } else {
                    Text("The first day will appear in Next Workout.")
                }
            }
        }
        .navigationTitle("Review Plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addDay() {
        draft.days.append(.init(name: "Day \(draft.days.count + 1)"))
    }

    private func removeDay(_ id: UUID) {
        draft.days.removeAll { $0.id == id }
    }

    private func activate() {
        guard draft.canActivate else { return }
        onActivate(draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                   draft.days.map { $0.makeRoutine() })
    }

    private struct ExerciseFields: View {
        @Binding var exercise: WorkoutImportDraft.Exercise

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Exercise name", text: $exercise.name)
                DisclosureGroup {
                    LabeledContent("Sets") {
                        TextField("Sets", value: $exercise.sets, format: .number)
                            .keyboardType(.numberPad)
                    }
                    Toggle("Timed exercise", isOn: $exercise.isTimed)
                    LabeledContent(exercise.isTimed ? "Duration (seconds)" : "Reps") {
                        TextField(exercise.isTimed ? "Duration" : "Reps", value: $exercise.amount, format: .number)
                            .keyboardType(.numberPad)
                    }
                    LabeledContent("Rest (seconds)") {
                        TextField("Rest", value: $exercise.rest, format: .number)
                            .keyboardType(.numberPad)
                    }
                } label: {
                    Text(exercise.isTimed
                         ? "\(exercise.sets) × \(exercise.amount) sec · \(exercise.rest) sec rest"
                         : "\(exercise.sets) × \(exercise.amount) reps · \(exercise.rest) sec rest")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.trailing)
            }
        }
    }
}
