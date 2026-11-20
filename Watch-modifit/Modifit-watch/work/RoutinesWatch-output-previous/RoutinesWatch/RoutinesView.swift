import SwiftUI

struct WorkoutRoutine: Identifiable, Hashable {
    let id: String
    let title: String
    let exerciseCount: Int
    let estimatedMinutes: Int
    let symbol: String

    static let all: [WorkoutRoutine] = [
        WorkoutRoutine(
            id: "full-body",
            title: "Full Body",
            exerciseCount: 8,
            estimatedMinutes: 41,
            symbol: "figure.strengthtraining.traditional"
        ),
        WorkoutRoutine(
            id: "lower-body",
            title: "Lower Body",
            exerciseCount: 5,
            estimatedMinutes: 25,
            symbol: "figure.walk"
        ),
        WorkoutRoutine(
            id: "upper-body",
            title: "Upper Body",
            exerciseCount: 5,
            estimatedMinutes: 25,
            symbol: "dumbbell.fill"
        )
    ]
}

struct RoutinesView: View {
    @State private var selectedRoutine: WorkoutRoutine?

    private let background = Color.black

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Routines")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.94, blue: 0.84))
                        .padding(.bottom, 9)

                    VStack(spacing: 8) {
                        ForEach(WorkoutRoutine.all) { routine in
                            Button {
                                selectedRoutine = routine
                            } label: {
                                RoutineCard(routine: routine)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 0)
                .padding(.bottom, 14)
            }
            .background(background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedRoutine) { routine in
                RoutineStartFlowView(routine: routine)
            }
        }
        .tint(Color(red: 1.0, green: 0.59, blue: 0.05))
    }

}

private struct RoutineCard: View {
    let routine: WorkoutRoutine

    private let cardColor = Color(red: 0.23, green: 0.095, blue: 0.055)
    private let tileColor = Color(red: 1.0, green: 0.82, blue: 0.71)
    private let iconColor = Color(red: 0.91, green: 0.28, blue: 0.02)
    private let detailColor = Color(red: 1.0, green: 0.60, blue: 0.02)

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: routine.symbol)
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34)
                .background(tileColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(routine.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.94, blue: 0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text("\(routine.exerciseCount) exercises · ~\(routine.estimatedMinutes) min")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 7)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, minHeight: 45, maxHeight: 45, alignment: .leading)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct RoutineStartFlowView: View {
    let routine: WorkoutRoutine
    @State private var hasStarted = false

    var body: some View {
        Group {
            if hasStarted {
                WorkoutSessionView(routine: routine)
            } else {
                StartScreenView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hasStarted = true
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
