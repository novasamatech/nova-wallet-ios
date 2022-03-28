import Foundation
import AVFoundation
import SoraFoundation

protocol QRScannerViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(session: AVCaptureSession)
    func present(message: String, animated: Bool)
}

protocol QRScannerWireframeProtocol: ApplicationSettingsPresentable, ImageGalleryPresentable {}

protocol QRScannerPresenterProtocol: AnyObject {
    func setup()
    func uploadGallery()
}
