import SwiftUI

// Esta vista compone la pantalla inicial Workouts con el diseño de referencia ModiFiT.
struct WorkoutsView: View {
    @ObservedObject var viewModel: WorkoutsViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                WorkoutHeaderView(userName: viewModel.userName, onAdd: viewModel.presentAddWorkout)
                TodaysWorkoutCard(workout: viewModel.todayWorkout)
                RoutinesSection(routines: viewModel.routines, onSelect: viewModel.select)
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavigationBar(selection: Binding(
                get: { viewModel.selectedTab },
                set: { viewModel.select($0) }
            ))
        }
    }
}

// Este encabezado muestra el saludo personalizado, el título y la acción de añadir rutina.
private struct WorkoutHeaderView: View {
    let userName: String
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Hello, \(userName)! 👋")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.text)
                Text("Workouts")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(AppColors.text)
            }
            Spacer(minLength: 0)
            Button {
                onAdd()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 58, height: 58)
                    .background(AppColors.accent.opacity(0.58), in: Circle())
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel("Add workout")
        }
    }
}

// Esta tarjeta resume el entrenamiento de hoy y mantiene la mascota dentro de su columna visual.
private struct TodaysWorkoutCard: View {
    let workout: TodayWorkout

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Today's Workout").font(.system(size: 22, weight: .bold, design: .rounded))
                Text(workout.name).font(.system(size: 18, weight: .medium, design: .rounded))
                Label("\(workout.exerciseCount) exercises", systemImage: "dumbbell.fill")
                Label("~ \(workout.estimatedMinutes) min (estimated)", systemImage: "timer")
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)

            FloatingMascotView()
                .frame(width: 132, height: 158)
                .accessibilityHidden(false)
        }
        .padding(.leading, 23).padding(.trailing, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 178)
        .background(AppColors.primary, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: AppColors.secondary.opacity(0.16), radius: 12, x: 0, y: 7)
    }
}

// Esta sección muestra las rutinas de ejemplo en tarjetas accesibles y seleccionables.
private struct RoutinesSection: View {
    let routines: [Routine]
    let onSelect: (Routine) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Routines")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .tracking(-0.45)
                .foregroundStyle(AppColors.text)

            ForEach(routines) { routine in
                Button { onSelect(routine) } label: { RoutineRowView(routine: routine) }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityHint("Show routine details")
            }
        }
    }
}

// Esta fila separa el símbolo, la descripción de la rutina y su indicador de navegación.
private struct RoutineRowView: View {
    let routine: Routine

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: routine.symbol)
                .font(.system(size: 29, weight: .medium))
                .foregroundStyle(AppColors.primary)
                .frame(width: 66, height: 66)
                .background(AppColors.accent.opacity(0.63), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(routine.name).font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                Text("\(routine.exerciseCount) exercises · ~ \(routine.estimatedMinutes) min")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 18, weight: .semibold)).foregroundStyle(AppColors.text)
        }
        .padding(.horizontal, 17).padding(.vertical, 17)
        .frame(maxWidth: .infinity, minHeight: 100)
        .appCard()
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
import SwiftUI

// Esta hoja presenta las dos opciones de incorporación de rutinas indicadas en el diseño.
struct AddWorkoutSheet: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 13) {
                Text("Choose how to add your training plan.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)

                FloatingMascotView().frame(height: 145).padding(.vertical, 2)

                NavigationLink { WorkoutScannerView() } label: {
                    AddWorkoutOption(title: "Scan Workout Plan", subtitle: "Take a photo or choose a file from your device.", symbol: "viewfinder")
                }.buttonStyle(SoftPressStyle())
                NavigationLink { AddWorkoutDestination(title: "Create Manually", symbol: "pencil") } label: {
                    AddWorkoutOption(title: "Create Manually", subtitle: "Add exercises, sets, reps and rest time.", symbol: "pencil")
                }.buttonStyle(SoftPressStyle())
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 21).padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Esta fila representa una acción de la hoja con una superficie táctil amplia.
private struct AddWorkoutOption: View {
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: symbol).font(.system(size: 22, weight: .medium)).foregroundStyle(AppColors.primary)
                .frame(width: 52, height: 52).background(AppColors.accent.opacity(0.62), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                Text(subtitle).font(.system(size: 13, weight: .regular, design: .rounded)).foregroundStyle(AppColors.secondaryText).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.secondary)
        }
        .padding(15).frame(maxWidth: .infinity, minHeight: 84).appCard()
    }
}

// Esta pantalla temporal confirma la opción elegida y deja preparada su ruta de navegación.
private struct AddWorkoutDestination: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 38)).foregroundStyle(AppColors.primary)
            Text(title).font(.title2.bold()).foregroundStyle(AppColors.text)
            Text("This feature will be available in a future update.")
                .font(.subheadline).foregroundStyle(AppColors.secondaryText).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

// Esta hoja muestra un resumen breve al abrir una rutina desde la lista.
struct RoutineDetailSheet: View {
    let routine: Routine
    @Binding var activeWorkout: Routine?
    let historyStore: WorkoutHistoryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: routine.symbol).font(.system(size: 36, weight: .medium)).foregroundStyle(AppColors.primary)
                .frame(width: 76, height: 76).background(AppColors.accent.opacity(0.63), in: Circle())
            Text(routine.name).font(.system(size: 25, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
            Text("\(routine.exerciseCount) exercises · ~ \(routine.estimatedMinutes) min")
                .font(.subheadline).foregroundStyle(AppColors.secondaryText)
            Text("Your workout is ready when you are.")
                .font(.footnote).foregroundStyle(AppColors.secondaryText).multilineTextAlignment(.center)
            Button {
                activeWorkout = routine
            } label: {
                Label("Start Workout", systemImage: "play.fill")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(AppColors.primary, in: Capsule())
            }
            .buttonStyle(.plain)
            Button("Done") { dismiss() }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .padding(24)
        .fullScreenCover(item: $activeWorkout) { routine in
            FocusWorkoutView(routine: routine, historyStore: historyStore)
        }
    }
}
