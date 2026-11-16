//
//  StartWorkoutView.swift
//  Watch
//
//  Created by Flavia Stabili on 16/11/2026.
//


import SwiftUI

// MARK: - Palette Colori (OLED-First + Accenti Brand)
extension Color {
    static let coralPeach = Color(red: 1.00, green: 0.56, blue: 0.45)     // #FF8E72
    static let coralLight = Color(red: 1.00, green: 0.72, blue: 0.65)     // #FFB8A6
    static let mintRecovery = Color(red: 0.49, green: 0.88, blue: 0.76)   // #7EE0C3
    static let mintLight = Color(red: 0.70, green: 0.96, blue: 0.88)      // #B2F5E1
    static let watchCardSurface = Color(red: 0.11, green: 0.11, blue: 0.12) // #1C1C1E
}

// MARK: - 1. Schermata Avvio ("Inizia")
struct StartWorkoutView: View {
    var onStart: () -> Void = {}

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Spacer(minLength: 2)

                MascotView(state: .ready)
                    .frame(width: 96, height: 108)

                Spacer(minLength: 4)

                Button(action: onStart) {
                    Label("INIZIA", systemImage: "play.fill")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.coralPeach, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            .navigationTitle("watch by Fla")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 2. Schermata Esercizio Attivo ("Upper Body" - 00:30)
struct ActiveWorkoutView: View {
    @State private var isPaused = false
    @State private var remainingSeconds = 30
    private let totalSeconds = 45

    private var progress: Double {
        Double(remainingSeconds) / Double(totalSeconds)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Arco di avanzamento inferiore + Timer
                TimerArcGauge(
                    progress: progress,
                    timeText: formattedTime(remainingSeconds),
                    accentColor: .coralPeach,
                    knobColor: .coralLight
                )
                .frame(height: 82)

                VStack(spacing: 4) {
                    MascotView(state: .workout)
                        .frame(width: 78, height: 84)

                    HStack {
                        CircularControlButton(
                            systemImage: isPaused ? "play.fill" : "pause.fill",
                            foreground: .coralPeach,
                            background: Color.white.opacity(0.14)
                        ) {
                            isPaused.toggle()
                        }

                        Spacer()

                        CircularControlButton(
                            systemImage: "forward.fill",
                            foreground: .coralPeach,
                            background: Color.white.opacity(0.14)
                        ) {
                            // Passa all'esercizio successivo
                        }
                    }
                    .padding(.horizontal, 6)

                    Spacer(minLength: 44)
                }
            }
            .padding(.horizontal, 6)
            .navigationTitle("Upper Body")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 3. Schermata Recupero ("Recupero" - 00:10)
struct RecoveryView: View {
    @State private var remainingSeconds = 10
    @State private var totalSeconds = 15

    private var progress: Double {
        min(1.0, Double(remainingSeconds) / Double(totalSeconds))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Arco menta per distinguere il recupero dallo sforzo
                TimerArcGauge(
                    progress: progress,
                    timeText: formattedTime(remainingSeconds),
                    accentColor: .mintRecovery,
                    knobColor: .mintLight
                )
                .frame(height: 82)

                VStack(spacing: 4) {
                    MascotView(state: .rest)
                        .frame(width: 78, height: 84)

                    HStack {
                        Button {
                            remainingSeconds += 15
                            totalSeconds += 15
                        } label: {
                            Text("+15s")
                                .font(.system(.footnote, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Color.mintRecovery)
                                .frame(width: 44, height: 44)
                                .background(Color.mintRecovery.opacity(0.16), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        CircularControlButton(
                            systemImage: "forward.fill",
                            foreground: .mintRecovery,
                            background: Color.mintRecovery.opacity(0.16)
                        ) {
                            // Salta il recupero
                        }
                    }
                    .padding(.horizontal, 6)

                    Spacer(minLength: 44)
                }
            }
            .padding(.horizontal, 6)
            .navigationTitle("Recupero")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 4. Schermata Lista Allenamenti ("Allenamenti")
struct WorkoutProgram: Identifiable {
    let id = UUID()
    let title: String
    let duration: String
    let icon: String
}

struct WorkoutListView: View {
    private let programs: [WorkoutProgram] = [
        WorkoutProgram(title: "Upper Body", duration: "45 min", icon: "dumbbell.fill"),
        WorkoutProgram(title: "Lower Body", duration: "50 min", icon: "figure.strengthtraining.functional"),
        WorkoutProgram(title: "Core & Mobility", duration: "25 min", icon: "figure.core.training"),
        WorkoutProgram(title: "Full Body", duration: "55 min", icon: "figure.mixed.cardio"),
        WorkoutProgram(title: "HIIT", duration: "20 min", icon: "bolt.fill")
    ]

    var body: some View {
        NavigationStack {
            List(programs) { program in
                NavigationLink {
                    ActiveWorkoutView()
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.coralPeach.opacity(0.18))
                                .frame(width: 34, height: 34)

                            Image(systemName: program.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.coralPeach)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(program.title)
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            Label(program.duration, systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 4)

                        Image(systemName: "ellipsis")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.watchCardSurface)
                )
            }
            .listStyle(.carousel)
            .navigationTitle("Allenamenti")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Componenti Riutilizzabili
struct CircularControlButton: View {
    let systemImage: String
    let foreground: Color
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: 44, height: 44) // Target minimo HIG 44x44 pt
                .background(background, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

struct TimerArcGauge: View {
    let progress: Double
    let timeText: String
    let accentColor: Color
    let knobColor: Color

    private let startAngle: Angle = .degrees(195)
    private let endAngle: Angle = .degrees(345)

    private var currentAngle: Angle {
        let span = endAngle.degrees - startAngle.degrees
        return .degrees(startAngle.degrees + span * progress)
    }

    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width * 0.44, 78)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height + 10)
            let rad = currentAngle.radians
            let knobPoint = CGPoint(
                x: center.x + radius * cos(rad),
                y: center.y + radius * sin(rad)
            )

            ZStack {
                // Traccia di sfondo
                ArcShape(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle)
                    .stroke(accentColor.opacity(0.22), style: StrokeStyle(lineWidth: 11, lineCap: .round))

                // Avanzamento attivo
                ArcShape(center: center, radius: radius, startAngle: startAngle, endAngle: currentAngle)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 11, lineCap: .round))

                // Indicatore circolare
                Circle()
                    .fill(knobColor)
                    .frame(width: 14, height: 14)
                    .position(knobPoint)

                // Cifre monospaziate per evitare oscillazioni
                Text(timeText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .position(x: center.x, y: geo.size.height - 14)
            }
        }
    }
}

struct ArcShape: Shape {
    let center: CGPoint
    let radius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

// MARK: - Mascotte Vettoriale (Sostituibile con Image("mascot_...") da Assets)
enum MascotState {
    case ready, workout, rest
}

struct MascotView: View {
    let state: MascotState

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 140.0
            context.translateBy(x: size.width / 2, y: size.height * 0.56)
            context.scaleBy(x: scale, y: scale)

            let outline = Color(red: 0.14, green: 0.07, blue: 0.05)
            let cream = Color(red: 1.0, green: 0.96, blue: 0.89)
            let cone = Color(red: 0.96, green: 0.73, blue: 0.31)
            let band = Color(red: 0.91, green: 0.29, blue: 0.24)

            // Cono waffle
            var conePath = Path()
            conePath.move(to: CGPoint(x: -24, y: 10))
            conePath.addLine(to: CGPoint(x: 24, y: 10))
            conePath.addLine(to: CGPoint(x: 0, y: 52))
            conePath.closeSubpath()
            context.fill(conePath, with: .color(cone))
            context.stroke(conePath, with: .color(outline), lineWidth: 3.5)

            // Testa gelato
            let headRect = CGRect(x: -32, y: -34, width: 64, height: 48)
            let headPath = Path(roundedRect: headRect, cornerRadius: 24)
            context.fill(headPath, with: .color(cream))
            context.stroke(headPath, with: .color(outline), lineWidth: 3.5)

            // Ciuffo superiore
            let swirlPath = Path(ellipseIn: CGRect(x: -16, y: -48, width: 32, height: 22))
            context.fill(swirlPath, with: .color(cream))
            context.stroke(swirlPath, with: .color(outline), lineWidth: 3.5)

            // Fascia rossa
            let bandPath = Path(roundedRect: CGRect(x: -33, y: -22, width: 66, height: 10), cornerRadius: 5)
            context.fill(bandPath, with: .color(band))
            context.stroke(bandPath, with: .color(outline), lineWidth: 3)

            // Occhi
            if state == .rest {
                var leftEye = Path()
                leftEye.move(to: CGPoint(x: -16, y: -2))
                leftEye.addQuadCurve(to: CGPoint(x: -8, y: -2), control: CGPoint(x: -12, y: 3))
                context.stroke(leftEye, with: .color(outline), lineWidth: 3)

                var rightEye = Path()
                rightEye.move(to: CGPoint(x: 8, y: -2))
                rightEye.addQuadCurve(to: CGPoint(x: 16, y: -2), control: CGPoint(x: 12, y: 3))
                context.stroke(rightEye, with: .color(outline), lineWidth: 3)

                // Goccia di sudore
                let sweat = Path(ellipseIn: CGRect(x: 22, y: -8, width: 8, height: 12))
                context.fill(sweat, with: .color(Color.cyan))
                context.stroke(sweat, with: .color(outline), lineWidth: 2)
            } else {
                context.fill(Path(ellipseIn: CGRect(x: -16, y: -6, width: 7, height: 7)), with: .color(outline))
                context.fill(Path(ellipseIn: CGRect(x: 9, y: -6, width: 7, height: 7)), with: .color(outline))
            }

            // Manubri nella schermata di allenamento
            if state == .workout {
                let leftWeight = Path(roundedRect: CGRect(x: -48, y: -12, width: 12, height: 20), cornerRadius: 3)
                let rightWeight = Path(roundedRect: CGRect(x: 36, y: -12, width: 12, height: 20), cornerRadius: 3)
                context.fill(leftWeight, with: .color(.gray))
                context.stroke(leftWeight, with: .color(outline), lineWidth: 2.5)
                context.fill(rightWeight, with: .color(.gray))
                context.stroke(rightWeight, with: .color(outline), lineWidth: 2.5)
            }
        }
    }
}

private func formattedTime(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

// MARK: - Xcode Previews (Tutte le 4 Schermate)
#Preview("01 · Avvio") {
    StartWorkoutView()
}

#Preview("02 · Esercizio Attivo") {
    ActiveWorkoutView()
}

#Preview("03 · Recupero") {
    RecoveryView()
}

#Preview("04 · Lista Allenamenti") {
    WorkoutListView()
}