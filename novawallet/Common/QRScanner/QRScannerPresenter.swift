import Foundation
import AVFoundation
import SoraFoundation

class QRScannerPresenter {
    weak var view: QRScannerViewProtocol?

    let qrScanService: QRCaptureServiceProtocol
    let wireframe: QRScannerWireframeProtocol
    let logger: LoggerProtocol?

    init(
        wireframe: QRScannerWireframeProtocol,
        qrScanService: QRCaptureServiceProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.wireframe = wireframe
        self.qrScanService = qrScanService
        self.logger = logger

        self.qrScanService.delegate = self
    }

    deinit {
        qrScanService.stop()
    }

    private func handleQRService(error: Error) {
        if let captureError = error as? QRCaptureServiceError {
            handleQRCaptureService(error: captureError)
        } else {
            logger?.error("Unexpected qr service error \(error)")
        }
    }

    private func handleQRCaptureService(error: QRCaptureServiceError) {
        guard let view = view else {
            return
        }

        let locale = view.selectedLocale
        switch error {
        case .deviceAccessRestricted:
            view.present(
                message: R.string.localizable.qrScanErrorCameraTitle(preferredLanguages: locale.rLanguages),
                animated: true
            )
        case .deviceAccessDeniedPreviously:
            let message = R.string.localizable.qrScanErrorCameraRestricted(preferredLanguages: locale.rLanguages)
            let title = R.string.localizable.qrScanErrorCameraTitle(preferredLanguages: locale.rLanguages)
            wireframe.askOpenApplicationSettings(with: message, title: title, from: view, locale: locale)
        default:
            break
        }
    }

    func handle(code _: String) {
        fatalError("Child presenter must override")
    }
}

extension QRScannerPresenter: QRScannerPresenterProtocol {
    func setup() {
        qrScanService.start()
    }
}

extension QRScannerPresenter: QRCaptureServiceDelegate {
    func qrCapture(service _: QRCaptureServiceProtocol, didSetup captureSession: AVCaptureSession) {
        DispatchQueue.main.async {
            self.view?.didReceive(session: captureSession)
        }
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didReceive code: String) {
        handle(code: code)
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didFailure error: Error) {
        DispatchQueue.main.async {
            self.handleQRService(error: error)
        }
    }
}
