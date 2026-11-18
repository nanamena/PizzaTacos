import Foundation
import Combine
import UIKit
import AVFoundation

// Este ViewModel valida, previsualiza y conserva localmente un plan de entrenamiento importado.
@MainActor
final class WorkoutScannerViewModel: ObservableObject {
    @Published private(set) var previewData: Data?
    @Published private(set) var savedURL: URL?
    @Published private(set) var fileName: String?
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var showingCamera = false
    @Published var showingContinueMessage = false
    @Published var showingPhotos = false
    @Published var showingImporter = false

    func prepareCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showError("A camera is not available on this device."); return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { allowed in
                Task { @MainActor in
                    if allowed { self.showingCamera = true }
                    else { self.showError("Camera access is off. Enable it in Settings to take a photo.") }
                }
            }
        default: showError("Camera access is off. Enable it in Settings to take a photo.")
        }
    }

    func importPhoto(_ data: Data, name: String) {
        guard UIImage(data: data) != nil else { showError("The selected photo could not be opened."); return }
        save(data: data, name: name.hasSuffix(".jpg") ? name : "\(name).jpg")
    }

    func importSelectedPhoto(_ data: Data, name: String) {
        guard UIImage(data: data) != nil else { showError("The selected photo could not be opened."); return }
        save(data: data, name: name)
    }

    func importFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            save(data: data, name: url.lastPathComponent)
        } catch { showError("This file could not be opened. Choose another PDF or image.") }
    }

    func confirmContinue() { showingContinueMessage = true }
    func reportImportFailure() { showError("The selected file could not be imported.") }

    private func save(data: Data, name: String) {
        do {
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("WorkoutPlans", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent(name)
            try data.write(to: destination, options: .atomic)
            previewData = data
            savedURL = destination
            fileName = name
        } catch { showError("The workout plan could not be saved on this device.") }
    }

    private func showError(_ message: String) { errorMessage = message; showingError = true }
}
