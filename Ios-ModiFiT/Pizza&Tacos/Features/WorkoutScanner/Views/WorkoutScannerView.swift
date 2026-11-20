import SwiftUI
import Photos
import UniformTypeIdentifiers
import UIKit

// Esta pantalla ofrece cámara, Fotos y Archivos, y abre la revisión tras leer las rutinas.
struct WorkoutScannerView: View {
    @Environment(\.appColors) private var appColors
    @Environment(\.scenePhase) private var scenePhase

    let onImportReady: (WorkoutImportDraft) -> Void
    @StateObject private var viewModel = WorkoutScannerViewModel()
    @State private var limitedPhotoPresenter = LimitedPhotoLibraryPresenter()
    @State private var pendingPhotoRejection: PhotoPickerRejection?
    @State private var rejectedPhotoIdentifier: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Scan Routine").font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(appColors.text)
                Text("Choose a photo or document to create routines.")
                    .font(.system(size: 14, design: .rounded)).foregroundStyle(appColors.secondaryText)
                if viewModel.isAnalyzing {
                    SwiftUI.ProgressView("Reading routines…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .appCard()
                }
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        sourceButton("Take Photo", symbol: "camera", action: viewModel.prepareCamera)
                        Text("ModiFiT uses the camera to capture your routine and read the exercises on this device.")
                            .font(.system(size: 12, design: .rounded)).foregroundStyle(appColors.secondaryText)
                            .padding(.horizontal, 12)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Button(action: viewModel.preparePhotos) {
                            sourceLabel("Choose from Photos", symbol: "photo")
                        }.buttonStyle(.plain)
                        Text("ModiFiT reads the photo you choose and saves a copy on this device. With limited access, the photo must also be in your allowed selection.")
                            .font(.system(size: 12, design: .rounded)).foregroundStyle(appColors.secondaryText)
                            .padding(.horizontal, 12)
                        if viewModel.photosAuthorizationStatus == .limited {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("The Apple picker can show your library. Add a photo to your allowed selection before importing it.")
                                    .font(.footnote)
                                    .foregroundStyle(appColors.secondaryText)
                                Button("Manage Selected Photos") {
                                    let presented = limitedPhotoPresenter.present { _ in
                                        viewModel.refreshPhotosAuthorizationStatus()
                                    }
                                    if !presented { openSettings() }
                                }
                                Button("Allow All Photos") { openSettings() }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        sourceButton("Choose from Files", symbol: "folder", action: { viewModel.showingImporter = true })
                        Text("ModiFiT reads the exercises from the PDF or image you choose and saves a copy on this device.")
                            .font(.system(size: 12, design: .rounded)).foregroundStyle(appColors.secondaryText)
                            .padding(.horizontal, 12)
                    }
                }
            }
            .frame(maxWidth: 600).padding(18).frame(maxWidth: .infinity, alignment: .top)
        }
        .background(appColors.background.ignoresSafeArea())
        .background(LimitedPhotoLibraryPresenterReader(presenter: limitedPhotoPresenter)
            .frame(width: 0, height: 0))
        .navigationTitle("Scan Routine").navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refreshPhotosAuthorizationStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refreshPhotosAuthorizationStatus() }
        }
        .onChange(of: viewModel.pendingOutcome?.id) { _, _ in presentPendingOutcomeIfReady() }
        .onChange(of: viewModel.showingCamera) { _, _ in presentPendingOutcomeIfReady() }
        .onChange(of: viewModel.showingPhotos) { _, _ in presentPendingOutcomeIfReady() }
        .onChange(of: viewModel.showingImporter) { _, _ in presentPendingOutcomeIfReady() }
        .fileImporter(isPresented: $viewModel.showingImporter, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { viewModel.importFile(url) }
            case .failure(let error):
                if (error as? CocoaError)?.code != .userCancelled { viewModel.reportImportFailure() }
            }
        }
        .fileDialogMessage("Choose a PDF or image so ModiFiT can read the exercises in your routine on this device.")
        .sheet(isPresented: $viewModel.showingPhotos, onDismiss: photoPickerDismissed) {
            NativePhotoLibraryPickerView(onSelect: { data, fileName in
                viewModel.importSelectedPhoto(data, name: fileName)
            }, onRejected: { rejection in
                pendingPhotoRejection = rejection
            }, onFailure: {
                viewModel.reportPhotoFailure()
            })
        }
        .sheet(isPresented: $viewModel.showingCamera, onDismiss: presentPendingOutcomeIfReady) {
            CameraCaptureView { image in
                guard let data = image.jpegData(compressionQuality: 0.9) else {
                    viewModel.reportPhotoFailure(source: .camera)
                    return
                }
                viewModel.importPhoto(data, name: "Workout-Camera-\(UUID().uuidString.prefix(8))")
            } onFailure: { viewModel.reportPhotoFailure(source: .camera) }
        }
        .alert(viewModel.errorTitle, isPresented: $viewModel.showingError) {
            if viewModel.retryOnlyError {
                Button("OK", role: .cancel) { }
            } else if viewModel.errorTitle == "Camera access is off" {
                Button("Open Settings") { openSettings() }
            } else if viewModel.errorTitle == "Photos access is off" {
                Button("Open Settings") { openSettings() }
            } else if viewModel.errorTitle == "Photo not in selected photos" {
                Button("Add to Selected Photos") { addRejectedPhotoToSelection() }
            } else if viewModel.errorTitle == "Can’t verify this photo" {
                Button("Choose Photo", action: viewModel.preparePhotos)
            } else if viewModel.errorTitle == "Camera unavailable" {
                Button("Choose Photo", action: viewModel.preparePhotos)
            } else {
                Button("Choose File") { viewModel.showingImporter = true }
            }
            if !viewModel.retryOnlyError {
                Button("Cancel", role: .cancel) { rejectedPhotoIdentifier = nil }
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private func photoPickerDismissed() {
        guard let rejection = pendingPhotoRejection else {
            presentPendingOutcomeIfReady()
            return
        }
        pendingPhotoRejection = nil
        switch rejection {
        case .notAllowed(let identifier):
            rejectedPhotoIdentifier = identifier
            viewModel.presentPhotoAccessAlert(
                title: "Photo not in selected photos",
                message: "Add this photo to your allowed selection, then choose it again to import your routine."
            )
        case .unverifiable:
            viewModel.presentPhotoAccessAlert(
                title: "Can’t verify this photo",
                message: "ModiFiT can’t confirm that this photo is in your allowed selection. Choose another photo."
            )
        case .permissionUnavailable:
            viewModel.preparePhotos()
        }
    }

    private func addRejectedPhotoToSelection() {
        guard let identifier = rejectedPhotoIdentifier else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            let presented = limitedPhotoPresenter.present { newlySelectedIdentifiers in
                viewModel.refreshPhotosAuthorizationStatus()
                let status = viewModel.photosAuthorizationStatus
                let isAllowed = status == .authorized ||
                    (status == .limited && (newlySelectedIdentifiers.contains(identifier) ||
                        PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject != nil))
                rejectedPhotoIdentifier = nil
                if isAllowed {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        viewModel.preparePhotos()
                    }
                }
            }
            if !presented {
                rejectedPhotoIdentifier = nil
                openSettings()
            }
        }
    }

    private func presentPendingOutcomeIfReady() {
        guard !viewModel.showingCamera, !viewModel.showingPhotos, !viewModel.showingImporter,
              let outcome = viewModel.pendingOutcome else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !viewModel.showingCamera, !viewModel.showingPhotos, !viewModel.showingImporter,
                  let outcome = viewModel.consumePendingOutcome(id: outcome.id) else { return }
            switch outcome.kind {
            case .review:
                guard let draft = viewModel.reviewDraft else { return }
                onImportReady(draft)
            case let .retry(title, message):
                viewModel.presentRetryAlert(title: title, message: message)
            }
        }
    }

    private func sourceButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { sourceLabel(title, symbol: symbol) }.buttonStyle(.plain)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func sourceLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 20, weight: .medium)).foregroundStyle(appColors.primary)
                .frame(width: 48, height: 48).background(appColors.accent.opacity(0.65), in: Circle())
            Text(title).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(appColors.text)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(appColors.secondaryText)
        }.padding(12).appCard()
    }
}

// Este representable usa el selector nativo de cámara y devuelve una foto capturada.
private struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onFailure: () -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, onFailure: onFailure, dismiss: dismiss) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onFailure: () -> Void
        let dismiss: DismissAction
        init(onCapture: @escaping (UIImage) -> Void, onFailure: @escaping () -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture; self.onFailure = onFailure; self.dismiss = dismiss
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
            else { onFailure() }
            dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { dismiss() }
    }
}
