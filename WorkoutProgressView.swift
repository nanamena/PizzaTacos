import SwiftUI

private enum ProgressPeriod: String, CaseIterable, Identifiable {
    case week = "Week", month = "Month", year = "Year"
    var id: Self { self }
    var component: Calendar.Component {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }
    var context: String {
        switch self {
        case .week: "this week"
        case .month: "this month"
        case .year: "this year"
        }
    }
}

private enum MuscleGroup: String, CaseIterable, Identifiable {
    case back = "Back", shoulders = "Shoulders", arms = "Arms"
    case core = "Core", glutes = "Glutes", legs = "Legs"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .back: "figure.strengthtraining.traditional"
        case .shoulders: "figure.arms.open"
        case .arms: "dumbbell"
        case .core: "figure.core.training"
        case .glutes: "figure.strengthtraining.functional"
        case .legs: "figure.walk"
        }
    }
}

// Isolated presentation data: saved workout templates are not completed sessions.
private struct ProgressActivity {
    let date: Date
    let minutes: Int
    let muscles: Set<MuscleGroup>

    static func examples(relativeTo now: Date, calendar: Calendar) -> [Self] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        let today = calendar.dateComponents([.day], from: week.start, to: now).day ?? 0
        let groups: [Set<MuscleGroup>] = [
            [.back, .shoulders, .arms], [.core, .glutes, .legs],
            [.back, .shoulders, .core], [.back, .shoulders, .arms]
        ]
        return (0..<48).compactMap { index in
            let weeksAgo = index / 4
            let offset = min(index % 4, today) - weeksAgo * 7
            guard let date = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
            return Self(date: date, minutes: [45, 50, 25, 50][index % 4], muscles: groups[index % 4])
        }
    }
}

struct WorkoutProgressView: View {
    @State private var period: ProgressPeriod = .week
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var colorScheme
    private let calendar = Calendar.current

    private var accent: Color {
        colorScheme == .dark ? Color(red: 1, green: 0.60, blue: 0.32)
            : Color(red: 0.72, green: 0.23, blue: 0.04)
    }

    var body: some View {
        // Re-evaluate the calendar window when the view refreshes, including midnight.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let activities = ProgressActivity.examples(relativeTo: now, calendar: calendar)
            let interval = calendar.dateInterval(of: period.component, for: now)
            let selected = activities.filter { activity in
                guard let interval else { return false }
                return activity.date >= interval.start && activity.date < interval.end
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Group {
                        if typeSize.isAccessibilitySize {
                            periodPicker.pickerStyle(.menu)
                        } else {
                            periodPicker.pickerStyle(.segmented)
                        }
                    }
                    .controlSize(.large)
                    .accessibilityIdentifier("progress.period")

                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: 12))
                        : AnyLayout(HStackLayout(spacing: 12))
                    layout {
                        statistic("Workouts", value: "\(selected.count)", symbol: "calendar", spoken: "\(selected.count) workouts")
                        let minutes = selected.reduce(0) { $0 + $1.minutes }
                        statistic("Training Time", value: duration(minutes), symbol: "clock",
                                  spoken: "\(minutes / 60) hours, \(minutes % 60) minutes of training")
                    }
                    muscleCard(selected)
                    consistencyCard(activities, now: now)
                    Label("Illustrative data, not your completed workouts.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
        }
        .background(WorkoutsScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
        .tint(accent)
    }

    private var periodPicker: some View {
        Picker("Progress period", selection: $period) {
            ForEach(ProgressPeriod.allCases) { Text($0.rawValue).tag($0) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Progress")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Your training at a glance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("DEMO")
                .font(.caption2.bold())
                .tracking(1)
                .foregroundStyle(accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accent.opacity(0.10), in: Capsule())
                .accessibilityLabel("Demo: showing sample activity")
        }
    }

    private func duration(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }

    private func statistic(_ title: String, value: String, symbol: String, spoken: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title3).foregroundStyle(accent)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(title).font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .progressCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private func cardHeading(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "calendar")
                .foregroundStyle(accent)
                .padding(6)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func muscleCard(_ activities: [ProgressActivity]) -> some View {
        let counts = Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { group in
            (group, activities.filter { $0.muscles.contains(group) }.count)
        })
        let maximum = max(counts.values.max() ?? 0, 1)
        let layout = typeSize >= .xxxLarge
            ? AnyLayout(VStackLayout(spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        return VStack(alignment: .leading, spacing: 16) {
            cardHeading("Muscle Training", subtitle: "Training frequency by body area (\(period.context)).")
            layout {
                HStack(spacing: 4) {
                    MuscleFigure(back: false, counts: counts, maximum: maximum)
                    MuscleFigure(back: true, counts: counts, maximum: maximum)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 218)
                .accessibilityHidden(true)
                VStack(spacing: 10) {
                    ForEach(MuscleGroup.allCases) { group in
                        let count = counts[group, default: 0]
                        HStack(spacing: 6) {
                            Image(systemName: group.symbol)
                                .font(.caption)
                                .frame(width: 24, height: 28)
                                .foregroundStyle(accent)
                                .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.rawValue).font(.caption.weight(.semibold))
                                GeometryReader { geometry in
                                    Capsule().fill(accent.opacity(0.10))
                                        .overlay(alignment: .leading) {
                                            Capsule().fill(LinearGradient(colors: [.orange.opacity(0.55), accent], startPoint: .leading, endPoint: .trailing))
                                                .frame(width: geometry.size.width * CGFloat(count) / CGFloat(maximum))
                                        }
                                }.frame(height: 6)
                            }
                            Text("\(count)×").font(.caption2).monospacedDigit()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(group.rawValue), \(count) workouts")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            VStack(spacing: 4) {
                Capsule().fill(LinearGradient(colors: [Color.orange.opacity(0.12), .orange, accent], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 7)
                HStack {
                    Text("Less trained")
                    Spacer()
                    Text("More trained")
                }.font(.caption2).foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)
        }
        .padding(14)
        .progressCard()
    }

    private func consistencyCard(_ activities: [ProgressActivity], now: Date) -> some View {
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        return VStack(alignment: .leading, spacing: 12) {
            cardHeading("How was your week?", subtitle: "Your training consistency this week.")
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(days, id: \.self) { day in dayCell(day, activities: activities, now: now) }
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(days, id: \.self) { day in
                        let trained = activities.contains { calendar.isDate($0.date, inSameDayAs: day) }
                        HStack {
                            Image(systemName: trained ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(trained ? accent : .secondary)
                            Text(day, format: .dateTime.weekday(.wide))
                            Spacer()
                            Text(day > now ? "Upcoming" : trained ? "Trained" : "Rest")
                                .foregroundStyle(.secondary)
                        }.font(.body)
                    }
                }
            }
        }
        .padding(14)
        .progressCard()
    }

    private func dayCell(_ day: Date, activities: [ProgressActivity], now: Date) -> some View {
        let trained = activities.contains { calendar.isDate($0.date, inSameDayAs: day) }
        let today = calendar.isDate(day, inSameDayAs: now)
        return VStack(spacing: 6) {
            ProgressMascot(celebrating: trained)
                .frame(width: 36, height: 53)
                .opacity(day > now ? 0.35 : 1)
            ZStack {
                Rectangle().fill(accent.opacity(0.20)).frame(height: 2)
                Circle().fill(trained ? accent : Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(accent, lineWidth: 1.5))
                if today {
                    Circle().stroke(accent, lineWidth: 1.5).frame(width: 14, height: 14)
                }
            }.frame(height: 16)
            Text(day, format: .dateTime.weekday(.narrow))
                .font(.caption2.weight(today ? .bold : .regular))
                .fixedSize()
        }
        .frame(minWidth: 38, maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).month().day()))
        .accessibilityValue(day > now ? "Upcoming" : trained ? "Trained" : "Rest day")
    }
}

private struct ProgressCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content
            .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(colorScheme == .dark ? 1 : 0.85),
                        in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.primary.opacity(0.035), lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 6, y: 3)
    }
}

private extension View {
    func progressCard() -> some View { modifier(ProgressCardModifier()) }
}

// Schematic front/back maps. The numeric frequency list is the accessible source of truth.
private struct MuscleFigure: View {
    let back: Bool
    let counts: [MuscleGroup: Int]
    let maximum: Int

    var body: some View {
        VStack(spacing: 4) {
            Canvas { context, size in
                let sx = size.width / 100
                let sy = size.height / 240
                func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
                    context.fill(Path(ellipseIn: CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy)), with: .color(color))
                }
                func region(_ points: [CGPoint], _ color: Color) {
                    var path = Path()
                    path.addLines(points.map { CGPoint(x: $0.x * sx, y: $0.y * sy) })
                    path.closeSubpath()
                    context.fill(path, with: .color(color))
                }
                func heat(_ group: MuscleGroup) -> Color {
                    let ratio = Double(counts[group, default: 0]) / Double(maximum)
                    return Color(red: 1, green: 0.76 - 0.40 * ratio, blue: 0.38 - 0.24 * ratio)
                        .opacity(ratio == 0 ? 0.15 : 0.85)
                }
                let skin = Color(red: 0.83, green: 0.77, blue: 0.70)
                ellipse(39, 3, 22, 29, skin)
                region([CGPoint(x: 43, y: 28), CGPoint(x: 57, y: 28), CGPoint(x: 60, y: 40), CGPoint(x: 40, y: 40)], skin)
                region([CGPoint(x: 29, y: 38), CGPoint(x: 71, y: 38), CGPoint(x: 68, y: 79), CGPoint(x: 61, y: 108), CGPoint(x: 66, y: 131), CGPoint(x: 34, y: 131), CGPoint(x: 39, y: 108), CGPoint(x: 32, y: 79)], skin)
                for right in [false, true] {
                    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: right ? 100 - x : x, y: y) }
                    region([p(29, 39), p(20, 45), p(15, 80), p(9, 113), p(10, 135), p(16, 138), p(20, 114), p(26, 88), p(35, 55)], skin)
                    region([p(34, 123), p(49, 127), p(47, 168), p(43, 202), p(42, 225), p(29, 229), p(30, 221), p(33, 198), p(31, 168)], skin)
                    ellipse(right ? 63 : 22, 39, 16, 25, heat(.shoulders))
                    ellipse(right ? 71 : 17, 62, 12, 35, heat(.arms))
                    ellipse(right ? 78 : 12, 96, 10, 26, heat(.arms).opacity(0.7))
                    ellipse(right ? 51 : 33, 134, 16, 42, heat(.legs))
                    ellipse(right ? 56 : 33, 179, 11, 36, heat(.legs).opacity(0.8))
                }
                if back {
                    region([CGPoint(x: 34, y: 43), CGPoint(x: 66, y: 43), CGPoint(x: 63, y: 80), CGPoint(x: 51, y: 105), CGPoint(x: 37, y: 80)], heat(.back))
                    ellipse(34, 109, 16, 26, heat(.glutes))
                    ellipse(50, 109, 16, 26, heat(.glutes))
                } else {
                    ellipse(33, 44, 17, 24, heat(.shoulders).opacity(0.65))
                    ellipse(50, 44, 17, 24, heat(.shoulders).opacity(0.65))
                    for row in 0..<4 {
                        ellipse(40, CGFloat(70 + row * 10), 9, 9, heat(.core))
                        ellipse(51, CGFloat(70 + row * 10), 9, 9, heat(.core))
                    }
                }
            }
            Text(back ? "Back" : "Front").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// Small vector ice-cream training mascots inspired by the supplied reference.
private struct ProgressMascot: View {
    let celebrating: Bool
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 48, y: size.height / 66)
            let ink = Color(red: 0.23, green: 0.14, blue: 0.10)
            func shape(_ path: Path, _ fill: Color) {
                context.fill(path, with: .color(fill))
                context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
            func line(_ points: [CGPoint], color: Color = Color(red: 0.23, green: 0.14, blue: 0.10)) {
                var path = Path(); path.addLines(points)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
            var cone = Path()
            cone.move(to: CGPoint(x: 13, y: 37)); cone.addLine(to: CGPoint(x: 24, y: 61)); cone.addLine(to: CGPoint(x: 35, y: 37)); cone.closeSubpath()
            shape(cone, Color(red: 1, green: 0.72, blue: 0.27))
            line([CGPoint(x: 17, y: 42), CGPoint(x: 28, y: 52)], color: .orange)
            line([CGPoint(x: 31, y: 42), CGPoint(x: 21, y: 53)], color: .orange)
            var cream = Path()
            cream.move(to: CGPoint(x: 10, y: 23))
            cream.addCurve(to: CGPoint(x: 17, y: 10), control1: CGPoint(x: 5, y: 14), control2: CGPoint(x: 16, y: 15))
            cream.addCurve(to: CGPoint(x: 28, y: 3), control1: CGPoint(x: 11, y: 2), control2: CGPoint(x: 25, y: 0))
            cream.addCurve(to: CGPoint(x: 38, y: 24), control1: CGPoint(x: 35, y: 9), control2: CGPoint(x: 39, y: 13))
            cream.closeSubpath()
            shape(cream, Color(red: 1, green: 0.96, blue: 0.85))
            shape(Path(ellipseIn: CGRect(x: 8, y: 18, width: 32, height: 27)), Color(red: 1, green: 0.96, blue: 0.85))
            shape(Path(roundedRect: CGRect(x: 7, y: 18, width: 34, height: 6), cornerRadius: 3), Color(red: 1, green: 0.48, blue: 0.31))
            for x in [18.0, 29.0] {
                context.fill(Path(ellipseIn: CGRect(x: x, y: 29, width: 2.5, height: 3)), with: .color(ink))
            }
            var smile = Path(); smile.move(to: CGPoint(x: 21, y: 35))
            smile.addQuadCurve(to: CGPoint(x: 28, y: 35), control: CGPoint(x: 24, y: 41))
            context.stroke(smile, with: .color(ink), lineWidth: 1.5)
            line([CGPoint(x: 13, y: 40), CGPoint(x: 4, y: celebrating ? 31 : 47)])
            line([CGPoint(x: 35, y: 40), CGPoint(x: 44, y: celebrating ? 31 : 47)])
            if celebrating {
                for x in [0.0, 39.0] {
                    shape(Path(roundedRect: CGRect(x: x, y: 27, width: 8, height: 9), cornerRadius: 3), .gray)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Progress — Light") {
    WorkoutsRootView(store: WorkoutStore(defaults: nil), initialTab: .progress)
        .preferredColorScheme(.light)
}

#Preview("Progress — Dark / Large Text") {
    WorkoutsRootView(store: WorkoutStore(defaults: nil), initialTab: .progress)
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility2)
}
