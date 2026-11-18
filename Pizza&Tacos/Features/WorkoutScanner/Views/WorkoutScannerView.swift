import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import PDFKit
import UIKit

// Esta pantalla ofrece cámara, Fotos y Archivos, y conserva una copia antes de continuar.
struct WorkoutScannerView: View {
    @StateObject private var viewModel = WorkoutScannerViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Scan Workout Plan").font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(AppColors.text)
                Text("Choose a photo or document to prepare your workout plan.")
                    .font(.system(size: 14, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                VStack(spacing: 10) {
                    sourceButton("Take Photo", symbol: "camera", action: viewModel.prepareCamera)
                    Button { viewModel.showingPhotos = true } label: {
                        sourceLabel("Choose from Photos", symbol: "photo")
                    }.buttonStyle(.plain)
                    sourceButton("Choose from Files", symbol: "folder", action: { viewModel.showingImporter = true })
                }
                if let data = viewModel.previewData, let name = viewModel.fileName {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(name).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(AppColors.text)
                        if name.lowercased().hasSuffix(".pdf"), let url = viewModel.savedURL {
                            PDFPlanPreview(url: url).frame(height: 330).clipShape(RoundedRectangle(cornerRadius: 16))
                        } else if let image = UIImage(data: data) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 350).frame(maxWidth: .infinity)
                        }
                        Button { viewModel.confirmContinue() } label: {
                            Text("Continue").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 52).background(AppColors.primary, in: Capsule())
                        }.buttonStyle(.plain)
                        Text("Your plan is saved on this device. Exercise recognition is not available yet.")
                            .font(.system(size: 12, design: .rounded)).foregroundStyle(AppColors.secondaryText)
                    }.padding(14).appCard()
                }
            }
            .frame(maxWidth: 600).padding(18).frame(maxWidth: .infinity, alignment: .top)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Scan Plan").navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $viewModel.showingImporter, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { viewModel.importFile(url) }
            case .failure: viewModel.reportImportFailure()
            }
        }
        .sheet(isPresented: $viewModel.showingPhotos) {
            PhotoLibraryPicker { data, fileName in
                viewModel.importSelectedPhoto(data, name: fileName)
            }
        }
        .sheet(isPresented: $viewModel.showingCamera) {
            CameraCaptureView { image in
                guard let data = image.jpegData(compressionQuality: 0.9) else { return }
                viewModel.importPhoto(data, name: "Workout-Camera-\(UUID().uuidString.prefix(8))")
            }
        }
        .alert(viewModel.showingError ? "Workout Plan" : "Plan Ready",
               isPresented: Binding(get: { viewModel.showingError || viewModel.showingContinueMessage }, set: { shown in
                   if !shown { viewModel.showingError = false; viewModel.showingContinueMessage = false }
               })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.showingError ? viewModel.errorMessage : "The selected plan has been preserved. Text recognition and exercise extraction will be added in a future update.")
        }
    }

    private func sourceButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { sourceLabel(title, symbol: symbol) }.buttonStyle(.plain)
    }

    private func sourceLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 20, weight: .medium)).foregroundStyle(AppColors.primary)
                .frame(width: 48, height: 48).background(AppColors.accent.opacity(0.65), in: Circle())
            Text(title).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(AppColors.text)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(AppColors.secondaryText)
        }.padding(12).appCard()
    }
}

// Este representable usa el selector nativo de cámara y devuelve una foto capturada.
private struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, dismiss: dismiss) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction
        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) { self.onCapture = onCapture; self.dismiss = dismiss }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
            dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { dismiss() }
    }
}

// Esta vista muestra páginas de PDF conservando la navegación y zoom nativos de PDFKit.
private struct PDFPlanPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; view.document = PDFDocument(url: url); return view }
    func updateUIView(_ view: PDFView, context: Context) { view.document = PDFDocument(url: url) }
}

// Este selector nativo de Photos entrega solo la imagen elegida, sin pedir acceso completo a la biblioteca.
private struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onSelect: (Data, String) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect, dismiss: dismiss) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(); configuration.filter = .images; configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration); picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) { }
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelect: (Data, String) -> Void
        let dismiss: DismissAction
        init(onSelect: @escaping (Data, String) -> Void, dismiss: DismissAction) { self.onSelect = onSelect; self.dismiss = dismiss }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else { dismiss(); return }
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [onSelect, dismiss] url, _ in
                guard let url, let data = try? Data(contentsOf: url) else { DispatchQueue.main.async { dismiss() }; return }
                let fileName = "Workout-Photo-\(UUID().uuidString.prefix(8)).\(url.pathExtension.isEmpty ? "jpg" : url.pathExtension)"
                DispatchQueue.main.async { onSelect(data, fileName); dismiss() }
            }
        }
    }
}
