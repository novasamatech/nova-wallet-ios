import UIKit
import Photos

final class QRScannerWireframe: NSObject, QRScannerWireframeProtocol {
    weak var presenter: ImageGalleryDelegate?

    private func presentGallery(
        from view: ControllerBackedProtocol?,
        delegate: ImageGalleryDelegate
    ) {
        presenter = delegate

        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self

        view?.controller.present(
            imagePicker,
            animated: true,
            completion: nil
        )
    }

    func presentImageGallery(from view: ControllerBackedProtocol?, delegate: ImageGalleryDelegate) {
        let photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus()
        switch photoAuthorizationStatus {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == PHAuthorizationStatus.authorized {
                        self.presentGallery(from: view, delegate: delegate)
                    } else {
                        delegate.didFail(in: self, with: ImageGalleryError.accessDeniedNow)
                    }
                }
            }
        case .restricted:
            delegate.didFail(in: self, with: ImageGalleryError.accessRestricted)
        case .denied:
            delegate.didFail(in: self, with: ImageGalleryError.accessDeniedPreviously)
        default:
            presentGallery(from: view, delegate: delegate)
        }
    }
}

extension QRScannerWireframe: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    @objc func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.presentingViewController?.dismiss(animated: true) {
            if let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                self.presenter?.didCompleteImageSelection(from: self, with: [originalImage])
            } else {
                self.presenter?.didCompleteImageSelection(from: self, with: [])
            }

            self.presenter = nil
        }
    }

    @objc func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.presentingViewController?.dismiss(animated: true) {
            self.presenter?.didCompleteImageSelection(from: self, with: [])

            self.presenter = nil
        }
    }
}
