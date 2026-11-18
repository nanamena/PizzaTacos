import SwiftUI

// Esta pantalla presenta tendencias calculadas únicamente desde sesiones finalizadas.
struct ProgressView: View {
    @StateObject private var viewModel: ProgressViewModel

    init(historyStore: WorkoutHistoryStore) {
        _viewModel = StateObject(wrappedValue: ProgressViewModel(historyStore: historyStore))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progress").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                    Text("Your training at a glance.").font(.system(size: 15, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                }
                periodSelector
                HStack(spacing: 10) {
                    statSection("Training Days") {
                        statCard(value: "\(viewModel.activeDayCount) / \(viewModel.periodDayCount)", symbol: "calendar")
                    }
                    statSection("Avg. per active day") {
                        statCard(value: viewModel.durationText(viewModel.averageDuration), symbol: "clock")
                    }
                }
                weeklyMoodCard
                moodSummaryCard
            }
            .frame(maxWidth: 620).padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 18).frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private var periodSelector: some View {
        VStack(spacing: 11) {
            Picker("Period", selection: Binding(get: { viewModel.period }, set: viewModel.selectPeriod)) {
                ForEach(ProgressPeriod.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Button { viewModel.move(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(viewModel.periodTitle).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(AppColors.text)
                Spacer()
                Button { viewModel.move(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(!viewModel.canGoForward).opacity(viewModel.canGoForward ? 1 : 0.35)
            }
            .font(.system(size: 16, weight: .semibold)).foregroundStyle(AppColors.primary)
            .buttonStyle(.plain)
        }
        .padding(13).appCard()
    }

    private func statSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.text)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func titledCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.text)
            content()
        }
    }

    private func statCard(value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.system(size: 19, weight: .semibold)).foregroundStyle(AppColors.primary)
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading).padding(13).appCard()
    }

    private var weeklyMoodCard: some View {
        titledCard("How Was Your Week?") {
            VStack(alignment: .leading, spacing: 12) {
                Text("How you felt after each workout.").font(.system(size: 12, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(viewModel.weekDays, id: \.self) { day in
                            let record = viewModel.record(on: day)
                            Button { viewModel.selectedDay = day } label: {
                                VStack(spacing: 5) {
                                    if let mood = record?.feeling {
                                        Image("ModiFiTMascot").resizable().scaledToFit().frame(width: 40, height: 40)
                                            .overlay(alignment: .bottomTrailing) { Image(systemName: mood.symbol).font(.system(size: 9, weight: .bold)).foregroundStyle(AppColors.primary) }
                                    } else {
                                        Circle().fill(AppColors.accent.opacity(0.5)).frame(width: 40, height: 40)
                                    }
                                    Text(day.formatted(.dateTime.weekday(.narrow))).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                                    if record != nil { Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(AppColors.primary) }
                                }
                                .frame(width: 44)
                                .frame(minHeight: 76)
                                .contentShape(Rectangle())
                                .background(viewModel.selectedDay.map { Calendar.current.isDate($0, inSameDayAs: day) } == true ? AppColors.accent.opacity(0.55) : .clear, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .disabled(record == nil)
                        }
                    }
                }
                if let selected = viewModel.selectedDay, let record = viewModel.record(on: selected) {
                    Text("\(record.routineName) · \(record.feeling?.rawValue ?? "No feedback")")
                        .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                }
            }
            .padding(15)
            .appCard()
        }
    }

    private var moodSummaryCard: some View {
        titledCard("Mood Summary") {
            VStack(alignment: .leading, spacing: 11) {
                if viewModel.moodTotal == 0 {
                    emptyState("Add feedback after a completed workout to see your mood summary.", symbol: "face.smiling")
                } else {
                    ForEach(viewModel.moodCounts, id: \.0) { mood, count in
                        HStack(spacing: 8) {
                            Image(systemName: mood.symbol).foregroundStyle(AppColors.primary).frame(width: 20)
                            Text(mood.rawValue).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(AppColors.text)
                            Spacer()
                            Text("\(viewModel.moodPercentages[mood, default: 0])%").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                        }
                    }
                }
            }
            .padding(15)
            .appCard()
        }
    }

    private func emptyState(_ text: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(AppColors.primary)
            Text(text).font(.system(size: 12, design: .rounded)).foregroundStyle(AppColors.secondaryText)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(AppColors.background, in: RoundedRectangle(cornerRadius: 14))
    }
}
