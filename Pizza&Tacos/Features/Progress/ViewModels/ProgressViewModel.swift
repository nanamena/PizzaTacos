import Foundation
import Combine

enum ProgressPeriod: String, CaseIterable, Identifiable {
    case week = "Week", month = "Month", year = "Year"
    var id: String { rawValue }
}

// Este ViewModel calcula las cifras visibles a partir del historial persistido.
@MainActor
final class ProgressViewModel: ObservableObject {
    @Published var period: ProgressPeriod = .week
    @Published var offset = 0
    @Published var selectedDay: Date?
    let historyStore: WorkoutHistoryStore
    private var cancellables = Set<AnyCancellable>()
    private var calendar: Calendar { var value = Calendar.current; value.firstWeekday = 2; return value }

    init(historyStore: WorkoutHistoryStore) {
        self.historyStore = historyStore
        historyStore.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var range: (start: Date, end: Date) {
        let now = Date()
        switch period {
        case .week:
            let current = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 7 * 86400)
            let start = calendar.date(byAdding: .weekOfYear, value: offset, to: current.start) ?? current.start
            return (start, calendar.date(byAdding: .day, value: 7, to: start) ?? start)
        case .month:
            let current = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 31 * 86400)
            let start = calendar.date(byAdding: .month, value: offset, to: current.start) ?? current.start
            return (start, calendar.date(byAdding: .month, value: 1, to: start) ?? start)
        case .year:
            let current = calendar.dateInterval(of: .year, for: now) ?? DateInterval(start: now, duration: 366 * 86400)
            let start = calendar.date(byAdding: .year, value: offset, to: current.start) ?? current.start
            return (start, calendar.date(byAdding: .year, value: 1, to: start) ?? start)
        }
    }

    var canGoForward: Bool { offset < 0 }
    var periodTitle: String {
        let formatter = DateFormatter(); formatter.locale = .current
        switch period {
        case .week:
            formatter.dateFormat = "MMM d"
            let last = calendar.date(byAdding: .day, value: -1, to: range.end) ?? range.end
            return "\(formatter.string(from: range.start)) – \(formatter.string(from: last))"
        case .month: formatter.dateFormat = "MMMM yyyy"
        case .year: formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: range.start)
    }

    var records: [WorkoutHistoryRecord] {
        historyStore.records.filter { $0.completedAt >= range.start && $0.completedAt < range.end }
    }
    var activeDayCount: Int {
        Set(records.map { calendar.startOfDay(for: $0.completedAt) }).count
    }
    var periodDayCount: Int {
        switch period {
        case .week: 7
        case .month: calendar.range(of: .day, in: .month, for: range.start)?.count ?? 30
        case .year: calendar.range(of: .day, in: .year, for: range.start)?.count ?? 365
        }
    }
    var averageDuration: Int {
        guard activeDayCount > 0 else { return 0 }
        return records.reduce(0) { $0 + $1.durationSeconds } / activeDayCount
    }
    var muscleCounts: [(String, Int)] {
        let names = ["Back", "Shoulders", "Arms", "Chest", "Core", "Glutes", "Legs"]
        return names.map { name in (name, records.filter { $0.muscleGroups.contains(name) }.count) }
    }
    var maxMuscleCount: Int { max(1, muscleCounts.map(\.1).max() ?? 0) }
    var moodCounts: [(WorkoutFeeling, Int)] {
        WorkoutFeeling.allCases.map { mood in (mood, records.filter { $0.feeling == mood }.count) }
    }
    var moodTotal: Int { moodCounts.reduce(0) { $0 + $1.1 } }
    var moodPercentages: [WorkoutFeeling: Int] {
        guard moodTotal > 0 else { return [:] }
        let values = moodCounts.map { mood, count in (mood, Double(count) * 100 / Double(moodTotal)) }
        var result = Dictionary(uniqueKeysWithValues: values.map { ($0.0, Int($0.1.rounded(.down))) })
        var remainder = 100 - result.values.reduce(0, +)
        for (mood, _) in values.sorted(by: { $0.1 - floor($0.1) > $1.1 - floor($1.1) }) where remainder > 0 {
            result[mood, default: 0] += 1
            remainder -= 1
        }
        return result
    }

    var weekDays: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    func record(on day: Date) -> WorkoutHistoryRecord? {
        historyStore.records.first { calendar.isDate($0.completedAt, inSameDayAs: day) }
    }
    func selectPeriod(_ value: ProgressPeriod) { period = value; offset = 0 }
    func move(_ direction: Int) { let next = offset + direction; if next <= 0 { offset = next } }
    func durationText(_ seconds: Int) -> String {
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours) h \(minutes) m" : "\(minutes) min"
    }
}
