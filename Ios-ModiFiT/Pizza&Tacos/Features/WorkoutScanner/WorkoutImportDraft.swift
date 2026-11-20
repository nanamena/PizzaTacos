import Foundation

struct WorkoutImportDraft: Equatable {
    var name: String
    var days: [Day]
    let recognizedText: String
    var unresolvedLines: [UnresolvedLine] = []

    struct UnresolvedLine: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let page: Int
        let dayID: UUID
    }

    struct Day: Identifiable, Equatable {
        let id = UUID()
        var name: String
        var exercises: [Exercise] = []

        var isValid: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !exercises.isEmpty && exercises.allSatisfy(\.isValid)
        }

        func makeRoutine(excluding previousSymbol: String? = nil) -> Routine {
            Routine(id: id.uuidString, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    symbol: Routine.randomGymSymbol(excluding: previousSymbol), exercises: exercises.map { $0.makeExercise() })
        }
    }

    struct Exercise: Identifiable, Equatable {
        let id = UUID()
        var name = ""
        var sets: Int?
        var amount: Int?
        var isTimed = false
        var rest: Int?
        var sourceLine: String?
        var sourcePage: Int?
        var reviewNotes: [String] = []

        mutating func addReviewNotes(_ notes: [String?]) {
            reviewNotes += notes.compactMap { $0 }
        }

        var isValid: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && sets.map { (1...99).contains($0) } == true
                && amount.map { (1...3600).contains($0) } == true
                && rest.map { (0...3600).contains($0) } == true
        }

        func makeExercise() -> FocusExercise {
            precondition(isValid)
            return FocusExercise(id: id.uuidString, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                          sets: sets!, repetitions: isTimed ? nil : amount,
                          durationSeconds: isTimed ? amount : nil, restSeconds: rest!, symbol: "dumbbell.fill")
        }
    }

    private static let dayHeading = #/^(?i:(?:day|giorno|giornata|allenamento|workout|scheda|sessione|session)\s+(?:\d{1,2}|[a-z])\b.*|lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica|monday|tuesday|wednesday|thursday|friday|saturday|sunday)$/#
    private static let prescription = #/^(.*?)\s+(\d{1,2})(?:\s*[-–—]\s*(\d{1,2}))?\s*[xX×]\s*(\d{1,4})(?:\s*[-–—]\s*(\d{1,4}))?(.*)$/#
    private static let columnPrescription = #/^\s*(\d{1,2})(?:\s*[-–—]\s*(\d{1,2}))?\s*[xX×]\s*(\d{1,4})(?:\s*[-–—]\s*(\d{1,4}))?(.*)$/#
    private static let duration = #/^\s*(\d{1,3})(?:\s*[-–—]\s*(\d{1,3}))?\s*(?i:min(?:uti|utes)?|m|s(?:ec(?:ondi|onds)?)?)\b.*$/#
    private static let prosePrescription = #/^(.*?)(?::\s*|\s+)(\d{1,2})(?:\s*[-–—]\s*(\d{1,2}))?\s*(?i:serie|series|sets?)\s*(?i:da|of)?\s*(\d{1,4})(?:\s*[-–—]\s*(\d{1,4}))?\s*(?i:ripetizioni|reps?|rep)?(.*)$/#

    init(fileName: String, result: WorkoutScanResult) {
        let fileTitle = (fileName as NSString).deletingPathExtension
        name = fileTitle.hasPrefix("Workout-Camera-") || fileTitle.hasPrefix("Workout-Photo-")
            ? "New Routine" : fileTitle
        recognizedText = result.text

        var parsedDays: [Day] = []
        var candidates: [UnresolvedLine] = []
        for source in result.lines {
            let line = source.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.wholeMatch(of: Self.dayHeading) != nil {
                parsedDays.append(Day(name: line))
            } else if var exercise = Self.parseExercise(line) {
                if parsedDays.isEmpty { parsedDays.append(Day(name: "Day 1")) }
                exercise.sourcePage = source.page
                parsedDays[parsedDays.count - 1].exercises.append(exercise)
            } else if Self.looksLikeExerciseRow(line) {
                if parsedDays.isEmpty { parsedDays.append(Day(name: "Day 1")) }
                candidates.append(.init(text: line, page: source.page, dayID: parsedDays[parsedDays.count - 1].id))
            }
        }
        days = parsedDays.isEmpty ? [Day(name: "Day 1")] : parsedDays
        unresolvedLines = candidates
    }

    private static func looksLikeExerciseRow(_ line: String) -> Bool {
        guard line.contains(where: \.isLetter) else { return false }
        let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
        if columns.count >= 2 {
            let valueIndex = columns.first?.trimmingCharacters(in: .whitespaces).allSatisfy(\.isNumber) == true ? 2 : 1
            guard valueIndex < columns.count else { return false }
            let value = String(columns[valueIndex])
            return value.contains(where: \.isNumber)
        }
        guard line.count < 90, !line.contains(".") else { return false }
        return line.firstMatch(of: #/\b\d{1,2}\s*[xX×]\s*\S+/#) != nil
            || line.firstMatch(of: #/(?i)\b\d{1,2}\s*(?:sets?|serie)\b/#) != nil
    }

    mutating func addUnresolvedLine(_ line: UnresolvedLine) {
        let columns = line.text.split(separator: "\t", omittingEmptySubsequences: false)
        let nameIndex = columns.first?.trimmingCharacters(in: .whitespaces).allSatisfy(\.isNumber) == true && columns.count > 1 ? 1 : 0
        let name = columns.isEmpty ? line.text : String(columns[nameIndex])
        let exercise = Exercise(name: name, sourceLine: line.text, sourcePage: line.page)
        let index = days.firstIndex { $0.id == line.dayID } ?? 0
        days[index].exercises.append(exercise)
        unresolvedLines.removeAll { $0.id == line.id }
    }

    mutating func ignoreUnresolvedLine(_ line: UnresolvedLine) {
        unresolvedLines.removeAll { $0.id == line.id }
    }

    func canSaveRoutines(for selectedDayIDs: Set<UUID>) -> Bool {
        let selectedDays = days.filter { selectedDayIDs.contains($0.id) }
        return !selectedDays.isEmpty
            && selectedDays.count == selectedDayIDs.count
            && selectedDays.allSatisfy(\.isValid)
            && !unresolvedLines.contains { selectedDayIDs.contains($0.dayID) }
    }

    private static func parseExercise(_ line: String) -> Exercise? {
        var columns = line.replacingOccurrences(of: #" {2,}"#, with: "\t", options: .regularExpression)
            .split(separator: "\t", omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        if columns.count > 1, !columns[0].isEmpty, columns[0].allSatisfy(\.isNumber) {
            columns.removeFirst()
        }
        if columns.count >= 2 {
            let name = columns[0]
            guard name.contains(where: \.isLetter) else { return nil }
            let value = columns[1]
            if let sets = parseCount(value, label: "Sets"), columns.count >= 3 {
                let timedAmount = parseDuration(columns[2])
                let amount = timedAmount ?? parseCount(columns[2], label: "Reps")
                let rest: (value: Int?, note: String?) = columns.count > 3 ? parseRestChoice(columns[3]) : (nil, nil)
                var exercise = Exercise(name: name, sets: sets.value, amount: amount?.value,
                                        isTimed: timedAmount != nil,
                                        rest: rest.value, sourceLine: line)
                exercise.addReviewNotes([sets.note, amount?.note, rest.note])
                return exercise
            }
            if let match = value.wholeMatch(of: columnPrescription), let sets = Int(match.1),
               let amount = Int(match.3) {
                let suffix = String(match.5)
                let isTimed = suffix.firstMatch(of: #/(?i)^\s*(?:min(?:uti|utes)?|m|s(?:ec(?:ondi|onds)?)?)\b/#) != nil
                let perSide = suffix.firstMatch(of: #/(?i)\bper\s+lato\b/#) != nil
                let selectedSets = selectLower(sets, match.2.flatMap { Int($0) }, label: "Sets")
                let minutes = suffix.firstMatch(of: #/(?i)^\s*(?:min(?:uti|utes)?|m)\b/#) != nil
                let selectedAmount = isTimed
                    ? selectDuration(amount, match.4.flatMap { Int($0) }, minutes: minutes)
                    : selectLower(amount, match.4.flatMap { Int($0) }, label: "Reps")
                let rest: (value: Int?, note: String?) = columns.count > 2 ? parseRestChoice(columns[2]) : (nil, nil)
                var exercise = Exercise(name: name, sets: selectedSets.value,
                                        amount: selectedAmount.value,
                                        isTimed: isTimed, rest: rest.value,
                                        sourceLine: line)
                exercise.addReviewNotes([selectedSets.note, selectedAmount.note, rest.note,
                                         perSide ? "Reps marked per side; check the value." : nil])
                return exercise
            }
            if let match = value.wholeMatch(of: duration), let amount = Int(match.1) {
                let minutes = value.firstMatch(of: #/(?i)\b(?:min(?:uti|utes)?|m)\b/#) != nil
                let selectedAmount = selectDuration(amount, match.2.flatMap { Int($0) }, minutes: minutes)
                let rest: (value: Int?, note: String?) = columns.count > 2 ? parseRestChoice(columns[2]) : (nil, nil)
                var exercise = Exercise(name: name, sets: 1,
                                        amount: selectedAmount.value,
                                        isTimed: true, rest: rest.value, sourceLine: line)
                exercise.addReviewNotes([selectedAmount.note, rest.note])
                return exercise
            }
            return nil
        }

        let rawName: String
        let sets: (value: Int, note: String?)
        let amount: (first: Int, second: Int?)
        let suffix: String
        if let match = line.wholeMatch(of: prescription),
           let parsedSets = Int(match.2), let parsedAmount = Int(match.4) {
            rawName = String(match.1)
            sets = selectLower(parsedSets, match.3.flatMap { Int($0) }, label: "Sets")
            amount = (parsedAmount, match.5.flatMap { Int($0) })
            suffix = String(match.6)
        } else if let match = line.wholeMatch(of: prosePrescription),
                  let parsedSets = Int(match.2), let parsedAmount = Int(match.4) {
            rawName = String(match.1)
            sets = selectLower(parsedSets, match.3.flatMap { Int($0) }, label: "Sets")
            amount = (parsedAmount, match.5.flatMap { Int($0) })
            suffix = String(match.6)
        } else { return nil }

        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ":-•")))
        guard name.contains(where: \.isLetter) else { return nil }
        let isTimed = suffix.firstMatch(of: #/^\s*(?i:s(?:ec(?:ondi|onds)?)?|min(?:uti|utes)?|m)\b/#) != nil
        let minutes = suffix.firstMatch(of: #/^\s*(?i:min(?:uti|utes)?|m)\b/#) != nil
        let selectedAmount = isTimed
            ? selectDuration(amount.first, amount.second, minutes: minutes)
            : selectLower(amount.first, amount.second, label: "Reps")
        let rest = parseRestChoice(suffix)
        var exercise = Exercise(name: name, sets: sets.value,
                                amount: selectedAmount.value,
                                isTimed: isTimed, rest: rest.value, sourceLine: line)
        exercise.addReviewNotes([sets.note, selectedAmount.note, rest.note])
        return exercise
    }

    private static func selectLower(_ first: Int, _ second: Int?, label: String) -> (value: Int, note: String?) {
        guard let second else { return (first, nil) }
        let selected = min(first, second)
        return (selected, "\(label) \(first)–\(second): initially filled \(selected).")
    }

    private static func selectDuration(_ first: Int, _ second: Int?, minutes: Bool) -> (value: Int, note: String?) {
        let selected = min(first, second ?? first)
        let seconds = selected * (minutes ? 60 : 1)
        guard let second else { return (seconds, nil) }
        let unit = minutes ? "min" : "sec"
        return (seconds, "Duration \(first)–\(second) \(unit): initially filled \(seconds) sec.")
    }

    private static func parseCount(_ text: String, label: String) -> (value: Int, note: String?)? {
        guard let match = text.wholeMatch(of: #/^\s*(\d{1,4})(?:\s*[-–—]\s*(\d{1,4}))?\s*(?i:reps?|ripetizioni)?\s*$/#),
              let first = Int(match.1) else { return nil }
        return selectLower(first, match.2.flatMap { Int($0) }, label: label)
    }

    private static func parseDuration(_ text: String) -> (value: Int, note: String?)? {
        guard let match = text.wholeMatch(of: duration), let first = Int(match.1) else { return nil }
        let minutes = text.firstMatch(of: #/(?i)\b(?:min(?:uti|utes)?|m)\b/#) != nil
        return selectDuration(first, match.2.flatMap { Int($0) }, minutes: minutes)
    }

    private static func parseRestChoice(_ text: String) -> (value: Int?, note: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let restLabel = trimmed.range(of: #"(?i)\b(?:rec(?:upero)?|rest|pausa|pause)\b"#,
                                      options: .regularExpression)
        let candidate = restLabel.map { String(trimmed[$0.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ":"))) } ?? trimmed
        if let match = candidate.wholeMatch(of: #/^\s*(\d{1,2}):(\d{2})\s*[-–—]\s*(\d{1,2}):(\d{2})\s*$/#),
           let firstMinutes = Int(match.1), let firstSeconds = Int(match.2), firstSeconds < 60,
           let secondMinutes = Int(match.3), let secondSeconds = Int(match.4), secondSeconds < 60 {
            let selected = min(firstMinutes * 60 + firstSeconds, secondMinutes * 60 + secondSeconds)
            return (selected, "Rest \(match.1):\(match.2)–\(match.3):\(match.4): initially filled \(selected) sec.")
        }
        if let match = candidate.wholeMatch(of: #/(?i)^\s*(\d{1,4})\s*[-–—]\s*(\d{1,4})\s*(min(?:uti|utes)?|m|s(?:ec(?:ondi|onds)?)?)?\s*$/#),
           let first = Int(match.1), let second = Int(match.2) {
            let minutes = match.3.map { String($0).lowercased().hasPrefix("m") } ?? false
            let selected = min(first, second) * (minutes ? 60 : 1)
            let unit = minutes ? "min" : "sec"
            return (selected, "Rest \(first)–\(second) \(unit): initially filled \(selected) sec.")
        }
        return (parseRest(text), nil)
    }

    private static func parseRest(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if ["—", "–", "-"].contains(trimmed) { return 0 }
        if trimmed.firstMatch(of: #/\b\d+\s*[-–—]\s*\d+\b/#) != nil { return nil }
        var rest: Int?
        if trimmed.firstMatch(of: #/(?i)\b(?:senza\s+recupero|no\s+rest|without\s+rest)\b/#) != nil {
            rest = 0
        } else if let match = trimmed.firstMatch(of: #/(?i)\b(?:rec(?:upero)?|rest|pausa|pause)?\s*:?\s*(\d{1,2}):(\d{2})\b/#),
                  let minutes = Int(match.1), let seconds = Int(match.2) {
            if seconds < 60 { rest = minutes * 60 + seconds }
        } else if let match = trimmed.firstMatch(of: #/(?i)\b(?:rec(?:upero)?|rest|pausa|pause)?\s*:?\s*(\d{1,3})\s*(?:min(?:uti|utes)?|m)\b(?:\s*(\d{1,2})\s*(?:s(?:ec(?:ondi|onds)?)?)?\b)?/#),
                  let minutes = Int(match.1) {
            let seconds = match.2.flatMap { Int($0) } ?? 0
            if seconds < 60 { rest = minutes * 60 + seconds }
        } else if let match = trimmed.firstMatch(of: #/(?i)\b(?:rec(?:upero)?|rest|pausa|pause)?\s*:?\s*(\d{1,4})\s*(?:s(?:ec(?:ondi|onds)?)?)?\b/#),
                  let seconds = Int(match.1) {
            rest = seconds
        }
        return rest
    }
}
