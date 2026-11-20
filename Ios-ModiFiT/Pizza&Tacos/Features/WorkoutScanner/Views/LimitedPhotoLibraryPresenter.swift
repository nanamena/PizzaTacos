import Photos
import PhotosUI
import SwiftUI

final class LimitedPhotoLibraryPresenter {
    weak var controller: UIViewController?

    @discardableResult
    func present(onFinish: @escaping ([String]) -> Void) -> Bool {
        guard let controller, controller.view.window != nil else { return false }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller) { identifiers in
            DispatchQueue.main.async { onFinish(identifiers) }
        }
        return true
    }
}

struct LimitedPhotoLibraryPresenterReader: UIViewControllerRepresentable {
    let presenter: LimitedPhotoLibraryPresenter

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        presenter.controller = controller
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        presenter.controller = controller
    }
}
