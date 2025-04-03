import Foundation
import AVFoundation
import Foundation_iOS

protocol QRScannerViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(session: AVCaptureSession)
    func present(message: String, animated: Bool)
}

protocol QRScannerWireframeProtocol: ApplicationSettingsPresentable, ImageGalleryPresentable {}

protocol QRScannerPresenterProtocol: AnyObject {
    func setup()
    func uploadGallery()
    func viewWillAppear()
    func viewDidDisappear()
}
