import SwiftUI

// Esta pantalla muestra información básica de la app y textos provisionales de privacidad.
struct AboutSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 13) {
                    Image(systemName: "info.circle.fill").font(.system(size: 38)).foregroundStyle(AppColors.primary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ModiFiT").font(.title3.bold()).foregroundStyle(AppColors.text)
                        Text("Version 1.0").font(.caption).foregroundStyle(AppColors.secondaryText)
                    }
                }.padding(17).settingsCardStyle()

                VStack(alignment: .leading, spacing: 9) {
                    Text("Privacy").font(.headline).foregroundStyle(AppColors.text)
                    Text("Your preferences are stored locally on this device. Permissions are requested only when you enable the related feature.")
                        .font(.subheadline).foregroundStyle(AppColors.secondaryText)
                }.padding(17).settingsCardStyle()

                VStack(alignment: .leading, spacing: 9) {
                    Text("Terms of Use").font(.headline).foregroundStyle(AppColors.text)
                    Text("Terms of use information will be available here.")
                        .font(.subheadline).foregroundStyle(AppColors.secondaryText)
                }.padding(17).settingsCardStyle()
            }
            .frame(maxWidth: 620).padding(20).frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
import SwiftUI
import UIKit

// Esta pantalla permite activar o desactivar recordatorios con autorización del sistema.
struct NotificationsSettingsView: View {
    @ObservedObject var viewModel: PermissionsViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose whether ModiFiT can send workout reminders and progress updates.")
                    .font(.system(size: 14, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                PermissionNotificationCard(isOn: viewModel.notificationsEnabled) { enabled in
                    Task { await viewModel.setNotificationsEnabled(enabled) }
                }
                Text("You can change notification access at any time in iOS Settings.")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(AppColors.secondaryText)
            }
            .frame(maxWidth: 620).padding(20).frame(maxWidth: .infinity, alignment: .top)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refreshNotificationAuthorization() }
        .alert("Notification settings", isPresented: alertBinding) {
            Button("Not Now", role: .cancel) { viewModel.alertMessage = nil }
            Button("Open Settings") {
                viewModel.alertMessage = nil
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(get: { viewModel.alertMessage != nil }, set: { if !$0 { viewModel.alertMessage = nil } })
    }
}

// Esta tarjeta muestra el control persistente de notificaciones de la aplicación.
private struct PermissionNotificationCard: View {
    let isOn: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: "bell.fill")
            VStack(alignment: .leading, spacing: 4) {
                Text("Workout Notifications").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(AppColors.text)
                Text("Workout reminders and progress updates.").font(.system(size: 12, design: .rounded)).foregroundStyle(AppColors.secondaryText)
            }
            Spacer(minLength: 5)
            Toggle("Notifications", isOn: Binding(get: { isOn }, set: onToggle))
                .labelsHidden().tint(.green).fixedSize().accessibilityLabel("Notifications")
        }
        .padding(14).settingsCardStyle()
    }
}
import SwiftUI
import UIKit

// Esta vista administra permisos de sistema y preferencias de ModiFiT sin simular autorizaciones.
struct PermissionsView: View {
    @ObservedObject var viewModel: PermissionsViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Text("Allow access to use these features in ModiFiT.")
                    .font(.system(size: 14, design: .rounded)).foregroundStyle(AppColors.secondaryText)

                VStack(spacing: 0) {
                    PermissionSettingRow(symbol: "mic.fill", title: "Microphone / VoiceOver",
                                         detail: "Microphone for voice features. VoiceOver is managed in iOS Settings.",
                                         isOn: viewModel.microphoneEnabled, onToggle: viewModel.setMicrophoneEnabled)
                    SettingsDivider()
                    PermissionSettingRow(symbol: "camera.fill", title: "Camera",
                                         detail: "Scan your workout plan.",
                                         isOn: viewModel.cameraEnabled, onToggle: viewModel.setCameraEnabled)
                    SettingsDivider()
                    PermissionSettingRow(symbol: "speaker.wave.2.fill", title: "Audio",
                                         detail: "Sounds, timers and notifications.",
                                         isOn: viewModel.audioEnabled, onToggle: viewModel.setAudioEnabled)
                    SettingsDivider()
                    HealthPermissionRow(viewModel: viewModel)
                }
                .padding(.horizontal, 14).settingsCardStyle()

                VStack(spacing: 0) {
                    PermissionSettingRow(symbol: "bell.fill", title: "Notifications",
                                         detail: "Workout reminders and progress updates.",
                                         isOn: viewModel.notificationsEnabled) { enabled in
                        Task { await viewModel.setNotificationsEnabled(enabled) }
                    }
                }
                .padding(.horizontal, 14).settingsCardStyle()

                Text("VoiceOver is an iOS accessibility feature. ModiFiT supports VoiceOver without a separate permission.")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.refreshCaptureAuthorization()
            await viewModel.refreshNotificationAuthorization()
            viewModel.refreshHealthAuthorization()
        }
        .alert("Permission settings", isPresented: alertBinding) {
            Button("Not Now", role: .cancel) { viewModel.alertMessage = nil }
            Button("Open Settings") {
                viewModel.alertMessage = nil
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(get: { viewModel.alertMessage != nil }, set: { if !$0 { viewModel.alertMessage = nil } })
    }
}

// Esta fila mantiene todos los permisos alineados y delega el cambio al ViewModel.
private struct PermissionSettingRow: View {
    let symbol: String
    let title: String
    let detail: String
    let isOn: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: symbol)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(AppColors.text)
                Text(detail).font(.system(size: 11, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 5)
            Toggle(title, isOn: Binding(get: { isOn }, set: onToggle))
                .labelsHidden().tint(.green).fixedSize()
                .accessibilityLabel(title)
        }
        .padding(.vertical, 13)
    }
}

// Esta fila presenta el flujo HealthKit con un estado explícito y permiso real.
private struct HealthPermissionRow: View {
    @ObservedObject var viewModel: PermissionsViewModel

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: "heart.fill")
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Health").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(AppColors.text)
                Text(healthDetail).font(.system(size: 11, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 5)
            if viewModel.healthAvailable {
                Button {
                    Task { await viewModel.requestHealthAccess() }
                } label: {
                    Text(viewModel.healthRequestSubmitted ? "Requested" : "Connect")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                }
                .disabled(viewModel.healthRequestSubmitted)
            } else {
                Image(systemName: "minus.circle").foregroundStyle(AppColors.secondaryText)
                    .accessibilityLabel("Apple Health unavailable")
            }
        }
        .padding(.vertical, 13)
    }

    private var healthDetail: String {
        if !viewModel.healthAvailable { return "Apple Health is unavailable on this device." }
        if viewModel.healthRequestSubmitted { return "Request sent. You can manage access in Apple Health." }
        return "Sync workouts and activity data."
    }
}

// Este divisor separa los controles dentro de la tarjeta de permisos.
private struct SettingsDivider: View {
    var body: some View {
        Rectangle().fill(AppColors.border).frame(height: 1).padding(.leading, 55)
    }
}

// Esta vista presenta el panel Settings y enlaza las preferencias con sus destinos.
struct SettingsView: View {
    @ObservedObject var themeStore: AppThemeStore
    @ObservedObject var workoutPreferences: WorkoutPreferencesStore
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var permissionsViewModel = PermissionsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Settings")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .tracking(-0.5).foregroundStyle(AppColors.text)
                        Text(viewModel.subtitle)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .padding(.bottom, 2)

                    AppearanceSettingsCard(themeStore: themeStore)
                    NavigationLink {
                        WorkoutPreferencesView(preferences: workoutPreferences)
                    } label: {
                        WorkoutPreferencesCard()
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        PermissionsView(viewModel: permissionsViewModel)
                    } label: {
                        SettingsNavigationRow(item: viewModel.navigationItems[0])
                    }.buttonStyle(.plain)

                    NavigationLink {
                        AboutSettingsView()
                    } label: {
                        SettingsNavigationRow(item: viewModel.navigationItems[1])
                    }.buttonStyle(.plain)
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(AppColors.primary)
    }
}

private struct WorkoutPreferencesCard: View {
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                SettingsIcon(symbol: "dumbbell.fill")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Workout Preferences")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                    Text("Sets, reps and rest for new exercises.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(16)
        .settingsCardStyle()
    }
}

private struct WorkoutPreferencesView: View {
    @ObservedObject var preferences: WorkoutPreferencesStore

    var body: some View {
        Form {
            Section {
                WorkoutSetStepper(value: $preferences.defaultSets, range: 1...10)
                ExerciseNumberField(title: "Repetitions", value: $preferences.defaultRepetitions, range: 1...30)
                WorkoutDurationPicker(title: "Rest", value: $preferences.defaultRestSeconds, range: 0...300)
            } footer: {
                Text("Applied automatically to each exercise in manually created workouts.")
            }
        }
        .navigationTitle("Workout Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Esta tarjeta agrupa el selector de apariencia y las cinco paletas disponibles.
private struct AppearanceSettingsCard: View {
    @ObservedObject var themeStore: AppThemeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 10) {
                SettingsIcon(symbol: "paintpalette")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Appearance").font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                    Text("App appearance and style.").font(.system(size: 12, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("App Theme").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(AppColors.text)
                HStack(spacing: 7) {
                    ForEach(AppAppearance.allCases) { appearance in
                        AppearanceChoice(appearance: appearance, isSelected: themeStore.appearance == appearance) {
                            withAnimation(.easeInOut(duration: 0.18)) { themeStore.appearance = appearance }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("App Palette").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(AppColors.text)
                HStack(spacing: 0) {
                    ForEach(AppPalette.allCases) { palette in
                        PaletteChoice(palette: palette, isSelected: themeStore.palette == palette) {
                            withAnimation(.easeInOut(duration: 0.18)) { themeStore.palette = palette }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(16).settingsCardStyle()
    }
}

// Este control presenta una opción de tema con su símbolo de sistema correspondiente.
private struct AppearanceChoice: View {
    let appearance: AppAppearance
    let isSelected: Bool
    let action: () -> Void

    private var symbol: String {
        switch appearance {
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        case .system: "circle.lefthalf.filled"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                Text(appearance.title).font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
            }
            .foregroundStyle(isSelected ? AppColors.surface : AppColors.text)
            .frame(maxWidth: .infinity, minHeight: 35)
            .background(isSelected ? AppColors.primary : AppColors.background, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? AppColors.primary : AppColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(appearance.title) appearance")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// Esta opción muestra cinco muestras de color y el estado seleccionado de la paleta.
private struct PaletteChoice: View {
    let palette: AppPalette
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                HStack(spacing: 2) {
                    ForEach(Array(palette.swatches.enumerated()), id: \.offset) { _, hex in
                        Rectangle().fill(Color(hex: hex)).frame(height: 16)
                    }
                }
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.border, lineWidth: 0.5))
                .padding(.horizontal, 3)
                Text(palette.name)
                    .font(.system(size: 9, weight: isSelected ? .bold : .regular, design: .rounded))
                    .foregroundStyle(AppColors.text).lineLimit(1).minimumScaleFactor(0.75)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13)).foregroundStyle(isSelected ? AppColors.primary : AppColors.border)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(palette.name) palette\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// Esta fila reutilizable presenta un destino de Settings con icono y chevron.
struct SettingsNavigationRow: View {
    let item: SettingsDestination

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: item.symbol)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                Text(item.subtitle).font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(AppColors.secondaryText)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 70)
        .settingsCardStyle()
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// Este componente mantiene el tamaño y el tratamiento de los iconos de Settings.
struct SettingsIcon: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(AppColors.primary)
            .frame(width: 43, height: 43)
            .background(AppColors.accent.opacity(0.52), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

// Este modificador mantiene consistentes las tarjetas, sus bordes y sus sombras.
extension View {
    func settingsCardStyle() -> some View {
        background(AppColors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppColors.border, lineWidth: 0.8))
            .shadow(color: AppColors.text.opacity(0.055), radius: 10, x: 0, y: 4)
    }
}
