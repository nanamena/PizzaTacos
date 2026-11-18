import AVFAudio
import AVFoundation
import Combine
import HealthKit
import UserNotifications

// Este ViewModel coordina las preferencias locales y las autorizaciones reales del sistema.
@MainActor
final class PermissionsViewModel: ObservableObject {
    @Published var microphoneEnabled = false
    @Published var cameraEnabled = false
    @Published var audioEnabled = UserDefaults.standard.bool(forKey: "modifit.audioEnabled")
    @Published var notificationsEnabled = UserDefaults.standard.bool(forKey: "modifit.notificationsEnabled")
    @Published var healthRequestSubmitted = UserDefaults.standard.bool(forKey: "modifit.healthRequestSubmitted")
    @Published var healthAvailable = HKHealthStore.isHealthDataAvailable()
    @Published var alertMessage: String?

    private let healthStore = HKHealthStore()

    init() {
        refreshCaptureAuthorization()
    }

    // Esta función sincroniza el interruptor local con el permiso vigente de notificaciones.
    func refreshNotificationAuthorization() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let systemAllowsNotifications = status == .authorized || status == .provisional || status == .ephemeral
        notificationsEnabled = systemAllowsNotifications && UserDefaults.standard.bool(forKey: "modifit.notificationsEnabled")
    }

    // Esta función vuelve a consultar los permisos de cámara y micrófono al abrir la pantalla.
    func refreshCaptureAuthorization() {
        microphoneEnabled = AVAudioApplication.shared.recordPermission == .granted
        cameraEnabled = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    // Esta función conserva si ya se presentó la solicitud, sin afirmar que el acceso fue concedido.
    func refreshHealthAuthorization() {
        healthAvailable = HKHealthStore.isHealthDataAvailable()
        healthRequestSubmitted = healthAvailable && UserDefaults.standard.bool(forKey: "modifit.healthRequestSubmitted")
    }

    // Esta función solicita permiso de micrófono al sistema solo cuando la persona lo activa.
    func setMicrophoneEnabled(_ enabled: Bool) {
        guard enabled else {
            microphoneEnabled = AVAudioApplication.shared.recordPermission == .granted
            if microphoneEnabled { alertMessage = "iOS manages microphone access. To turn it off, use iOS Settings." }
            return
        }
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            microphoneEnabled = true
        case .denied:
            microphoneEnabled = false
            alertMessage = "Microphone access is off. You can allow it in iOS Settings."
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                guard let self else { return }
                Task { @MainActor in
                    self.microphoneEnabled = granted
                    if !granted { self.alertMessage = "Microphone access was not allowed. You can change this in iOS Settings." }
                }
            }
        @unknown default:
            microphoneEnabled = false
        }
    }

    // Esta función solicita acceso real a la cámara cuando se activa su control.
    func setCameraEnabled(_ enabled: Bool) {
        guard enabled else {
            cameraEnabled = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
            if cameraEnabled { alertMessage = "iOS manages camera access. To turn it off, use iOS Settings." }
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraEnabled = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                Task { @MainActor in
                    self.cameraEnabled = granted
                    if !granted { self.alertMessage = "Camera access was not allowed. You can change this in iOS Settings." }
                }
            }
        case .denied, .restricted:
            cameraEnabled = false
            alertMessage = "Camera access is off. You can allow it in iOS Settings."
        @unknown default:
            cameraEnabled = false
        }
    }

    // Esta función guarda la preferencia de sonido dentro de ModiFiT.
    func setAudioEnabled(_ enabled: Bool) {
        audioEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "modifit.audioEnabled")
    }

    // Esta función solicita notificaciones reales y guarda la preferencia de recordatorios.
    func setNotificationsEnabled(_ enabled: Bool) async {
        if !enabled {
            notificationsEnabled = false
            UserDefaults.standard.set(false, forKey: "modifit.notificationsEnabled")
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationsEnabled = true
            UserDefaults.standard.set(true, forKey: "modifit.notificationsEnabled")
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                notificationsEnabled = granted
                UserDefaults.standard.set(granted, forKey: "modifit.notificationsEnabled")
                if !granted { alertMessage = "Notifications were not allowed. You can change this in iOS Settings." }
            } catch {
                notificationsEnabled = false
                alertMessage = "Notifications could not be enabled. Please try again."
            }
        case .denied:
            notificationsEnabled = false
            alertMessage = "Notifications are off. You can allow them in iOS Settings."
        @unknown default:
            notificationsEnabled = false
        }
    }

    // Esta función presenta el consentimiento HealthKit para leer y guardar entrenamientos.
    func requestHealthAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthAvailable = false
            alertMessage = "Apple Health is not available on this device."
            return
        }
        let workoutType = HKObjectType.workoutType()
        do {
            try await healthStore.requestAuthorization(toShare: [workoutType], read: [workoutType])
            healthRequestSubmitted = true
            UserDefaults.standard.set(true, forKey: "modifit.healthRequestSubmitted")
        } catch {
            alertMessage = "Apple Health access could not be requested. Please try again."
        }
    }
}
import SwiftUI
import Combine

// Este ViewModel prepara los datos que necesita el panel principal de Settings.
@MainActor
final class SettingsViewModel: ObservableObject {
    let subtitle = "Customize your training experience."
    let navigationItems = [
        SettingsDestination(title: "Permissions", subtitle: "Manage app access.", symbol: "lock.shield"),
        SettingsDestination(title: "Notifications", subtitle: "Workout reminders and updates.", symbol: "bell.fill"),
        SettingsDestination(title: "About", subtitle: "App version, terms and privacy.", symbol: "info.circle")
    ]
}

// Este modelo contiene el título, el subtítulo y el símbolo de cada fila navegable.
struct SettingsDestination: Identifiable {
    let title: String
    let subtitle: String
    let symbol: String
    var id: String { title }
}
