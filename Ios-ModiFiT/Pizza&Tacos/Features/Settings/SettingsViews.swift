import SwiftUI

// Esta pantalla muestra información básica de la app y textos provisionales de privacidad.
struct AboutSettingsView: View {
    @Environment(\.appColors) private var appColors

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 13) {
                    Image(systemName: "info.circle.fill").font(.system(size: 38)).foregroundStyle(appColors.primary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ModiFiT").font(.title3.bold()).foregroundStyle(appColors.text)
                        Text("Version 1.0").font(.caption).foregroundStyle(appColors.secondaryText)
                    }
                }.padding(17).settingsCardStyle()

                VStack(alignment: .leading, spacing: 9) {
                    Text("Privacy").font(.headline).foregroundStyle(appColors.text)
                    Text("ModiFiT sends routines to your paired Apple Watch and syncs completed workout summaries back to this iPhone. When you connect Apple Health, ModiFiT saves completed workouts there and reads Apple's active energy for those workouts. ModiFiT doesn't estimate calories or infer muscle groups.")
                        .font(.subheadline).foregroundStyle(appColors.secondaryText)
                }.padding(17).settingsCardStyle()

                VStack(alignment: .leading, spacing: 9) {
                    Text("Terms of Use").font(.headline).foregroundStyle(appColors.text)
                    Text("Terms of use information will be available here.")
                        .font(.subheadline).foregroundStyle(appColors.secondaryText)
                }.padding(17).settingsCardStyle()
            }
            .frame(maxWidth: 620).padding(20).frame(maxWidth: .infinity)
        }
        .background(appColors.background.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
import SwiftUI
import UIKit

// Esta pantalla permite activar o desactivar recordatorios con autorización del sistema.
struct NotificationsSettingsView: View {
    @Environment(\.appColors) private var appColors

    @ObservedObject var viewModel: PermissionsViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose whether ModiFiT can send workout reminders and progress updates.")
                    .font(.system(size: 14, design: .rounded)).foregroundStyle(appColors.secondaryText)
                PermissionNotificationCard(isOn: viewModel.notificationsEnabled) { enabled in
                    Task { await viewModel.setNotificationsEnabled(enabled) }
                }
                Text("You can change notification access at any time in iOS Settings.")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(appColors.secondaryText)
            }
            .frame(maxWidth: 620).padding(20).frame(maxWidth: .infinity, alignment: .top)
        }
        .background(appColors.background.ignoresSafeArea())
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
    @Environment(\.appColors) private var appColors

    let isOn: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: "bell.fill")
            VStack(alignment: .leading, spacing: 4) {
                Text("Workout Notifications").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(appColors.text)
                Text("Workout reminders and progress updates.").font(.system(size: 12, design: .rounded)).foregroundStyle(appColors.secondaryText)
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
    @Environment(\.appColors) private var appColors

    @ObservedObject var viewModel: PermissionsViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Text("Allow access to use these features in ModiFiT.")
                    .font(.system(size: 14, design: .rounded)).foregroundStyle(appColors.secondaryText)

                VStack(spacing: 0) {
                    PermissionSettingRow(symbol: "mic.fill", title: "Microphone / VoiceOver",
                                         detail: "Microphone for voice features. VoiceOver is managed in iOS Settings.",
                                         isOn: viewModel.microphoneEnabled, onToggle: viewModel.setMicrophoneEnabled)
                    SettingsDivider()
                    PermissionSettingRow(symbol: "camera.fill", title: "Camera",
                                         detail: "Scan your routine.",
                                         isOn: viewModel.cameraEnabled, onToggle: viewModel.setCameraEnabled)
                    SettingsDivider()
                    PermissionSettingRow(symbol: "speaker.wave.2.fill", title: "Audio",
                                         detail: "Sounds, timers and notifications.",
                                         isOn: viewModel.audioEnabled, onToggle: viewModel.setAudioEnabled)
                    SettingsDivider()
                    HealthPermissionRow()
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
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(appColors.secondaryText)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .background(appColors.background.ignoresSafeArea())
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.refreshCaptureAuthorization()
            await viewModel.refreshNotificationAuthorization()
            AppleHealthAccess.shared.refresh()
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
    @Environment(\.appColors) private var appColors

    let symbol: String
    let title: String
    let detail: String
    let isOn: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: symbol)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(appColors.text)
                Text(detail).font(.system(size: 11, design: .rounded)).foregroundStyle(appColors.secondaryText)
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
    @Environment(\.appColors) private var appColors
    @ObservedObject private var healthAccess = AppleHealthAccess.shared
    @State private var showAccessHelp = false

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: "heart.fill")
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Health").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(appColors.text)
                Text(healthDetail).font(.system(size: 11, design: .rounded)).foregroundStyle(appColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 5)
            if healthAccess.isAvailable {
                Button {
                    if healthAccess.savesWorkouts {
                        healthAccess.disable()
                    } else {
                        Task {
                            if !(await healthAccess.enable()) {
                                showAccessHelp = true
                            }
                        }
                    }
                } label: {
                    Text(healthAccess.savesWorkouts ? "Stop Saving" : "Connect")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(appColors.primary)
                }
            } else {
                Image(systemName: "minus.circle").foregroundStyle(appColors.secondaryText)
                    .accessibilityLabel("Apple Health unavailable")
            }
        }
        .padding(.vertical, 13)
        .alert("Apple Health access", isPresented: $showAccessHelp) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Open the Health app and review ModiFiT's Workout permissions.")
        }
    }

    private var healthDetail: String {
        if !healthAccess.isAvailable { return "Apple Health is unavailable on this device." }
        if healthAccess.savesWorkouts { return "Save completed workouts. Show Apple's active energy when available." }
        if healthAccess.canWriteWorkouts { return "Workout access is allowed. Saving is off in ModiFiT." }
        return "Connect to save completed workouts and see Apple Health energy."
    }
}

// Este divisor separa los controles dentro de la tarjeta de permisos.
private struct SettingsDivider: View {
    @Environment(\.appColors) private var appColors

    var body: some View {
        Rectangle().fill(appColors.border).frame(height: 1).padding(.leading, 55)
    }
}

// Esta vista presenta el panel Settings y enlaza las preferencias con sus destinos.
struct SettingsView: View {
    @Environment(\.appColors) private var appColors

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
                            .tracking(-0.5).foregroundStyle(appColors.text)
                        Text(viewModel.subtitle)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(appColors.secondaryText)
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
            .background(appColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(appColors.primary)
    }
}

private struct WorkoutPreferencesCard: View {
    @Environment(\.appColors) private var appColors

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                SettingsIcon(symbol: "dumbbell.fill")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Workout Preferences")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(appColors.text)
                    Text("Sets, reps and rest for new exercises.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(appColors.secondaryText)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(appColors.secondaryText)
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

// Esta tarjeta agrupa las cinco paletas disponibles.
private struct AppearanceSettingsCard: View {
    @Environment(\.appColors) private var appColors

    @ObservedObject var themeStore: AppThemeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 10) {
                SettingsIcon(symbol: "paintpalette")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Appearance").font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(appColors.text)
                    Text("Choose your color palette.").font(.system(size: 12, design: .rounded)).foregroundStyle(appColors.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("App Palette").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(appColors.text)
                HStack(spacing: 0) {
                    ForEach(AppPalette.allCases) { palette in
                        PaletteChoice(palette: palette, isSelected: themeStore.palette == palette) {
                            themeStore.palette = palette
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(16).settingsCardStyle()
    }
}

// Esta opción muestra cinco muestras de color y el estado seleccionado de la paleta.
private struct PaletteChoice: View {
    @Environment(\.appColors) private var appColors

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
                .overlay(Capsule().stroke(appColors.border, lineWidth: 0.5))
                .padding(.horizontal, 3)
                Text(palette.name)
                    .font(.system(size: 9, weight: isSelected ? .bold : .regular, design: .rounded))
                    .foregroundStyle(appColors.text).lineLimit(1).minimumScaleFactor(0.75)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13)).foregroundStyle(isSelected ? appColors.primary : appColors.border)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
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
    @Environment(\.appColors) private var appColors

    let item: SettingsDestination

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: item.symbol)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(appColors.text)
                Text(item.subtitle).font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(appColors.secondaryText)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(appColors.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 70)
        .settingsCardStyle()
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// Este componente mantiene el tamaño y el tratamiento de los iconos de Settings.
struct SettingsIcon: View {
    @Environment(\.appColors) private var appColors

    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(appColors.primary)
            .frame(width: 43, height: 43)
            .background(appColors.accent.opacity(0.52), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

// Este modificador mantiene consistentes las tarjetas, sus bordes y sus sombras.
extension View {
    func settingsCardStyle() -> some View {
        modifier(SettingsCardStyle())
    }
}

private struct SettingsCardStyle: ViewModifier {
    @Environment(\.appColors) private var appColors

    func body(content: Content) -> some View {
        content
            .background(appColors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(appColors.border, lineWidth: 0.8))
            .shadow(color: appColors.text.opacity(0.055), radius: 10, x: 0, y: 4)
    }
}
