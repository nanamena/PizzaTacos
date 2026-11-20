import Foundation
import Combine
import UIKit
import AVFoundation
import ImageIO
import PDFKit
import Photos

// Este ViewModel valida, lee y conserva localmente un plan de entrenamiento importado.
@MainActor
final class WorkoutScannerViewModel: ObservableObject {
    @Published private(set) var savedURL: URL?
    @Published var showingError = false
    @Published var errorTitle = "Routine"
    @Published var errorMessage = ""
    @Published private(set) var retryOnlyError = false
    @Published var showingCamera = false
    @Published var showingPhotos = false
    @Published private(set) var photosAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var showingImporter = false
    @Published var reviewDraft: WorkoutImportDraft?
    @Published private(set) var isAnalyzing = false
    @Published private(set) var pendingOutcome: ScanOutcome?

    enum Source { case camera, photos, files }
    struct ScanOutcome: Identifiable {
        enum Kind {
            case review
            case retry(title: String, message: String)
        }

        let id: UUID
        let kind: Kind
    }

    private(set) var source: Source = .files

    private var analysisTask: Task<Void, Never>?
    private var documentID = UUID()


    func prepareCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showError("Camera unavailable", "Choose a photo or file instead."); return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { allowed in
                Task { @MainActor in
                    if allowed { self.showingCamera = true }
                    else { self.showError("Camera access is off", "Enable camera access in Settings or choose a photo or file.") }
                }
            }
        default: showError("Camera access is off", "Enable camera access in Settings or choose a photo or file.")
        }
    }

    func preparePhotos() {
        refreshPhotosAuthorizationStatus()
        guard photosAuthorizationStatus == .notDetermined else {
            handlePhotosAuthorization(photosAuthorizationStatus)
            return
        }
        Task {
            let result = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            handlePhotosAuthorization(result)
        }
    }

    func refreshPhotosAuthorizationStatus() {
        photosAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    private func handlePhotosAuthorization(_ status: PHAuthorizationStatus) {
        photosAuthorizationStatus = status
        switch status {
        case .authorized, .limited:
            showingPhotos = true
        case .denied:
            showError("Photos access is off", "Allow access to photos in Settings, or choose a file instead.")
        case .restricted:
            showError("Photos access is restricted", "Photo access is restricted on this device. You can choose a file instead.")
        case .notDetermined:
            break
        @unknown default:
            showError("Photos unavailable", "Choose a photo or file again.")
        }
    }

    func importPhoto(_ data: Data, name: String) {
        source = .camera
        guard UIImage(data: data) != nil else { queueRetry("Can’t read this photo", retryMessage); return }
        save(data: data, name: name.hasSuffix(".jpg") ? name : "\(name).jpg", source: .camera, isPDF: false)
    }

    func importSelectedPhoto(_ data: Data, name: String) {
        source = .photos
        guard UIImage(data: data) != nil else { queueRetry("Can’t read this photo", retryMessage); return }
        save(data: data, name: name, source: .photos, isPDF: false)
    }

    func importFile(_ url: URL) {
        source = .files
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            let isPDF = PDFDocument(data: data) != nil
            let isImage = CGImageSourceCreateWithData(data as CFData, nil) != nil
            guard isPDF || isImage || url.pathExtension.lowercased() == "pdf" else {
                queueRetry("Unsupported file type", "Choose a readable PDF or image of your routine.")
                return
            }
            save(data: data, name: url.lastPathComponent, source: .files,
                 isPDF: isPDF || !isImage && url.pathExtension.lowercased() == "pdf")
        } catch { queueRetry("Can’t open this file", retryMessage) }
    }

    func reportImportFailure() {
        source = .files
        queueRetry("Can’t open this file", retryMessage)
    }

    func reportPhotoFailure(source: Source = .photos) {
        self.source = source
        queueRetry("Can’t read this photo", retryMessage)
    }

    private func save(data: Data, name: String, source: Source, isPDF: Bool) {
        let currentID = clearCurrentImport()
        self.source = source
        do {
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("WorkoutPlans", isDirectory: true)
                .appendingPathComponent(currentID.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent(name)
            try data.write(to: destination, options: .atomic)
            savedURL = destination
            isAnalyzing = true
            analysisTask = Task { [weak self] in
                let result: Result<WorkoutScanResult, Error>
                do { result = .success(try await WorkoutPlanTextReader.read(data, isPDF: isPDF)) }
                catch { result = .failure(error) }
                guard !Task.isCancelled, let self, self.documentID == currentID else { return }
                self.isAnalyzing = false
                self.analysisTask = nil
                switch result {
                case .success(let scan):
                    if scan.findings.contains(where: { Self.requiresNewCopy($0.issue) }) {
                        self.rejectScan(id: currentID, title: "Can’t read this routine", message: self.retryMessage)
                        return
                    }
                    let draft = WorkoutImportDraft(fileName: name, result: scan)
                    guard draft.days.contains(where: { !$0.exercises.isEmpty }) else {
                        self.rejectScan(id: currentID, title: "No exercises found", message: self.retryMessage)
                        return
                    }
                    self.reviewDraft = draft
                    self.pendingOutcome = .init(id: currentID, kind: .review)
                case .failure(let error):
                    switch error as? WorkoutScanError {
                    case .lockedPDF:
                        self.rejectScan(id: currentID, title: "PDF is password-protected", message: "Choose an unlocked copy of the PDF.")
                    case .emptyPDF:
                        self.rejectScan(id: currentID, title: "PDF has no pages", message: "Choose a PDF that contains a readable routine.")
                    default:
                        self.rejectScan(id: currentID, title: "Can’t read this routine", message: self.retryMessage)
                    }
                }
            }
        } catch { queueRetry("Can’t save a copy", "Try importing the routine again.") }
    }

    @discardableResult
    func clearCurrentImport() -> UUID {
        analysisTask?.cancel()
        analysisTask = nil
        documentID = UUID()
        pendingOutcome = nil
        reviewDraft = nil
        savedURL = nil
        isAnalyzing = false
        return documentID
    }

    func consumePendingOutcome(id: UUID) -> ScanOutcome? {
        guard let pendingOutcome, pendingOutcome.id == id else { return nil }
        self.pendingOutcome = nil
        return pendingOutcome
    }

    func presentRetryAlert(title: String, message: String) {
        showError(title, message, retryOnly: true)
    }

    func presentPhotoAccessAlert(title: String, message: String) {
        showError(title, message)
    }

    private static func requiresNewCopy(_ issue: WorkoutScanResult.Issue) -> Bool {
        switch issue {
        case .tooDark, .blurry, .textTooSmall, .hardToRead, .noText, .pageUnreadable, .noExercises: true
        }
    }

    private var retryMessage: String {
        switch source {
        case .camera: "Retake the photo with brighter, even lighting and keep the routine in focus."
        case .photos: "Choose a clearer photo with the full routine visible and well lit."
        case .files: "Choose a clearer PDF or image with legible exercise details."
        }
    }

    private func queueRetry(_ title: String, _ message: String) {
        let currentID = clearCurrentImport()
        pendingOutcome = .init(id: currentID, kind: .retry(title: title, message: message))
    }

    private func rejectScan(id: UUID, title: String, message: String) {
        reviewDraft = nil
        savedURL = nil
        pendingOutcome = .init(id: id, kind: .retry(title: title, message: message))
    }

    private func showError(_ title: String, _ message: String, retryOnly: Bool = false) {
        errorTitle = title
        errorMessage = message
        retryOnlyError = retryOnly
        showingError = true
    }
}
