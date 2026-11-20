import Foundation

struct WorkoutImportDraft {
    var name: String
    var days: [Day]
    let recognizedText: String

    struct Day: Identifiable {
        let id = UUID()
        var name: String
        var exercises: [Exercise] = []

        var isValid: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !exercises.isEmpty && exercises.allSatisfy(\.isValid)
        }

        func makeRoutine() -> Routine {
            Routine(id: id.uuidString, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    symbol: "dumbbell.fill", exercises: exercises.map { $0.makeExercise() })
        }
    }

    struct Exercise: Identifiable {
        let id = UUID()
        var name = ""
        var sets = 3
        var amount = 10
        var isTimed = false
        var rest = 60

        var isValid: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (1...99).contains(sets) && (1...3600).contains(amount) && (0...3600).contains(rest)
        }

        func makeExercise() -> FocusExercise {
            FocusExercise(id: id.uuidString, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                          sets: sets, repetitions: isTimed ? nil : amount,
                          durationSeconds: isTimed ? amount : nil, restSeconds: rest, symbol: "dumbbell.fill")
        }
    }

    private static let dayHeading = #/^(?i:(?:day|giorno|giornata|allenamento|workout|scheda|sessione|session)\s+(?:\d{1,2}|[a-z])\b.*|lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica|monday|tuesday|wednesday|thursday|friday|saturday|sunday)$/#
    private static let prescription = #/^(.*?)\s+(\d{1,2})\s*[xX×]\s*(\d{1,4})(?:\s*[-–]\s*\d+)?(.*)$/#
    private static let amountAndRest = #/^\s*(?:(?i:(min(?:uti)?|s(?:ec(?:ondi)?)?|["″]|reps?|rip(?:etizioni)?))\.?)?(?:[\s,;|–-]+(?:(?i:rest|rec(?:upero)?|pausa)\.?\s*:?\s*)?(\d{1,4})(?::(\d{2}))?\s*(?i:(min(?:uti)?|s(?:ec(?:ondi)?)?|["″]))?)?\s*$/#

    init(fileName: String, recognizedText: String) {
        let fileTitle = (fileName as NSString).deletingPathExtension
        name = fileTitle.hasPrefix("Workout-Camera-") || fileTitle.hasPrefix("Workout-Photo-")
            ? "Training Plan" : fileTitle
        self.recognizedText = recognizedText

        var parsedDays: [Day] = []
        for rawLine in recognizedText.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.wholeMatch(of: Self.dayHeading) != nil {
                parsedDays.append(Day(name: line))
            } else if let exercise = Self.parseExercise(line) {
                if parsedDays.isEmpty { parsedDays.append(Day(name: "Day 1")) }
                parsedDays[parsedDays.count - 1].exercises.append(exercise)
            }
        }
        days = parsedDays.isEmpty ? [Day(name: "Day 1")] : parsedDays
    }

    var canActivate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !days.isEmpty && days.allSatisfy(\.isValid)
    }

    private static func parseExercise(_ line: String) -> Exercise? {
        let columns = line.replacingOccurrences(of: #"\t+| {2,}"#, with: "\t", options: .regularExpression)
            .split(separator: "\t")
        // Support tables with separate name, sets, reps and optional rest columns.
        let entry: String
        if columns.count >= 3, Int(columns[1].trimmingCharacters(in: .whitespaces)) != nil {
            entry = "\(columns[0]) \(columns[1])×\(columns.dropFirst(2).joined(separator: " "))"
        } else {
            entry = line
        }

        guard let match = entry.wholeMatch(of: prescription),
              let sets = Int(match.2), let amount = Int(match.3) else { return nil }
        let name = match.1.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.contains(where: \.isLetter) else { return nil }
        let suffix = match.4.wholeMatch(of: amountAndRest)
        let unit = suffix?.1?.lowercased()
        let isTimed = unit.map { !$0.hasPrefix("r") } ?? false
        let value = unit?.hasPrefix("min") == true ? amount * 60 : amount
        var rest = 60
        if let restValue = suffix?.2.flatMap({ Int($0) }) {
            if let seconds = suffix?.3.flatMap({ Int($0) }) {
                rest = restValue * 60 + seconds
            } else {
                rest = suffix?.4?.lowercased().hasPrefix("min") == true ? restValue * 60 : restValue
            }
        }
        return Exercise(name: name, sets: sets, amount: value, isTimed: isTimed, rest: rest)
    }
}
