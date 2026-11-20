import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct NativePhotoLibraryPickerView: UIViewControllerRepresentable {
    let onSelect: (Data, String) -> Void
    let onRejected: (PhotoPickerRejection) -> Void
    let onFailure: () -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, onRejected: onRejected, onFailure: onFailure, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) { }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelect: (Data, String) -> Void
        let onRejected: (PhotoPickerRejection) -> Void
        let onFailure: () -> Void
        let dismiss: DismissAction

        init(onSelect: @escaping (Data, String) -> Void,
             onRejected: @escaping (PhotoPickerRejection) -> Void,
             onFailure: @escaping () -> Void,
             dismiss: DismissAction) {
            self.onSelect = onSelect
            self.onRejected = onRejected
            self.onFailure = onFailure
            self.dismiss = dismiss
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                dismiss()
                return
            }

            switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
            case .authorized:
                break
            case .limited:
                guard let identifier = result.assetIdentifier else {
                    onRejected(.unverifiable)
                    dismiss()
                    return
                }
                guard PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject != nil else {
                    onRejected(.notAllowed(identifier))
                    dismiss()
                    return
                }
            default:
                onRejected(.permissionUnavailable)
                dismiss()
                return
            }

            let provider = result.itemProvider
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [self] url, _ in
                let data = url.flatMap { try? Data(contentsOf: $0) }
                let fileExtension = url.flatMap { $0.pathExtension.isEmpty ? nil : $0.pathExtension } ?? "jpg"
                DispatchQueue.main.async {
                    if let data {
                        let name = "Workout-Photo-\(UUID().uuidString.prefix(8)).\(fileExtension)"
                        self.onSelect(data, name)
                    } else {
                        self.onFailure()
                    }
                    self.dismiss()
                }
            }
        }
    }
}

enum PhotoPickerRejection {
    case notAllowed(String)
    case unverifiable
    case permissionUnavailable
}
