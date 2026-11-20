import Combine
import SwiftUI

@main
struct ModiFiTWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRoutinesView()
                .tint(WatchPalette.gold)
                .preferredColorScheme(.dark)
        }
    }
}

private enum WatchPalette {
    static let background = Color.black
    static let card = Color(red: 0.20, green: 0.11, blue: 0.08)
    static let cream = Color(red: 1.00, green: 0.96, blue: 0.88)
    static let gold = Color(red: 1.00, green: 0.68, blue: 0.00)
    static let peach = Color(red: 0.98, green: 0.84, blue: 0.75)
    static let orange = Color(red: 0.82, green: 0.34, blue: 0.12)
}

private struct WatchRoutine: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let exerciseCount: Int
    let estimatedMinutes: Int

    static let samples = [
        WatchRoutine(id: "prova", name: "Prova", symbol: "dumbbell.fill", exerciseCount: 2, estimatedMinutes: 6),
        WatchRoutine(id: "lower", name: "Lower Body", symbol: "figure.walk", exerciseCount: 5, estimatedMinutes: 25),
        WatchRoutine(id: "full", name: "Full Body", symbol: "figure.strengthtraining.traditional", exerciseCount: 8, estimatedMinutes: 41)
    ]
}

private struct WatchRoutinesView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Routines")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchPalette.cream)
                        .padding(.horizontal, 4)

                    ForEach(WatchRoutine.samples) { routine in
                        NavigationLink {
                            WatchRoutineDetailView(routine: routine)
                        } label: {
                            WatchRoutineRow(routine: routine)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .background(WatchPalette.background)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct WatchRoutineRow: View {
    let routine: WatchRoutine

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: routine.symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(WatchPalette.orange)
                .frame(width: 38, height: 38)
                .background(WatchPalette.peach, in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchPalette.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("\(routine.exerciseCount) exercises · ~\(routine.estimatedMinutes) min")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(WatchPalette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WatchPalette.card, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct WatchRoutineDetailView: View {
    let routine: WatchRoutine

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: routine.symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(WatchPalette.orange)
                .frame(width: 54, height: 54)
                .background(WatchPalette.peach, in: RoundedRectangle(cornerRadius: 18))

            Text(routine.name)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(WatchPalette.cream)
                .multilineTextAlignment(.center)

            Text("\(routine.exerciseCount) exercises")
                .font(.caption)
                .foregroundStyle(WatchPalette.cream.opacity(0.8))

            Text("~\(routine.estimatedMinutes) min")
                .font(.caption)
                .foregroundStyle(WatchPalette.gold)

            NavigationLink {
                WatchWorkoutSessionView(routine: routine)
            } label: {
                Text("Start")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchPalette.gold)
        }
        .padding(.horizontal, 8)
        .background(WatchPalette.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WatchWorkoutSessionView: View {
    let routine: WatchRoutine
    @State private var remainingSeconds = 20
    @State private var isPaused = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timeText: String {
        String(format: "0:%02d", remainingSeconds)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(routine.name)
                .font(.caption2)
                .foregroundStyle(WatchPalette.cream.opacity(0.8))
                .lineLimit(1)

            Text(timeText)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(WatchPalette.cream)

            HStack(spacing: 6) {
                Button("+15 s") {
                    remainingSeconds += 15
                }
                .tint(WatchPalette.card)

                Button("Next") {
                    remainingSeconds = 20
                    isPaused = false
                }
                .tint(WatchPalette.gold)
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))

            Button(isPaused ? "Resume" : "Pause") {
                isPaused.toggle()
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tint(WatchPalette.cream)
        }
        .padding(.horizontal, 6)
        .background(WatchPalette.background)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            guard !isPaused, remainingSeconds > 0 else { return }
            remainingSeconds -= 1
        }
    }
}
