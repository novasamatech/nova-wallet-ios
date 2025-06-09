import Foundation
import AVFoundation
import Foundation_iOS

class QRScannerPresenter: QRScannerPresenterProtocol {
    weak var view: QRScannerViewProtocol?

    let qrScanService: QRCaptureServiceProtocol
    let qrExtractionService: QRExtractionServiceProtocol
    let wireframe: QRScannerWireframeProtocol
    let logger: LoggerProtocol?

    private var isRunning: Bool = false

    init(
        wireframe: QRScannerWireframeProtocol,
        qrScanService: QRCaptureServiceProtocol,
        qrExtractionService: QRExtractionServiceProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.wireframe = wireframe
        self.qrScanService = qrScanService
        self.qrExtractionService = qrExtractionService
        self.logger = logger

        self.qrScanService.delegate = self
    }

    deinit {
        stopServiceIfNeeded()
    }

    private func startServiceIfNeeded() {
        guard !isRunning else {
            return
        }

        isRunning = true

        qrScanService.start()
    }

    private func stopServiceIfNeeded() {
        guard isRunning else {
            return
        }

        isRunning = false

        qrScanService.stop()
    }

    private func handleQRService(error: Error) {
        if let captureError = error as? QRCaptureServiceError {
            handleQRCaptureService(error: captureError)
        } else if let extractionError = error as? QRExtractionServiceError {
            handleQRExtractionService(error: extractionError)
        } else if let imageGalleryError = error as? ImageGalleryError {
            handleImageGallery(error: imageGalleryError)
        }

        logger?.error("Unexpected qr service error \(error)")
    }

    private func handleQRCaptureService(error: QRCaptureServiceError) {
        guard let view = view else {
            return
        }

        let locale = view.selectedLocale
        switch error {
        case .deviceAccessRestricted:
            view.present(
                message: R.string.localizable.qrScanErrorCameraRestricted(
                    preferredLanguages: locale.rLanguages
                ),
                animated: true
            )
        case .deviceAccessDeniedPreviously:
            let message = R.string.localizable.qrScanErrorCameraRestricted(preferredLanguages: locale.rLanguages)
            let title = R.string.localizable.qrScanErrorCameraTitle(preferredLanguages: locale.rLanguages)
            wireframe.askOpenApplicationSettings(with: message, title: title, from: view, locale: locale)
        case .unsupportedFormat:
            view.present(
                message: R.string.localizable.commonUnsupportedQrCode(
                    preferredLanguages: locale.rLanguages
                ),
                animated: true
            )
        default:
            break
        }
    }

    private func handleQRExtractionService(error: QRExtractionServiceError) {
        let locale = view?.selectedLocale
        switch error {
        case .noFeatures:
            view?.present(
                message: R.string.localizable.qrScanErrorNoInfo(
                    preferredLanguages: locale?.rLanguages
                ),
                animated: true
            )
        case .detectorUnavailable, .invalidImage:
            view?.present(
                message: R.string.localizable.qrScanErrorInvalidImage(
                    preferredLanguages: locale?.rLanguages
                ),
                animated: true
            )
        }
    }

    private func handleImageGallery(error: ImageGalleryError) {
        let locale = view?.selectedLocale
        switch error {
        case .accessRestricted:
            view?.present(
                message: R.string.localizable.qrScanErrorGalleryRestricted(
                    preferredLanguages: locale?.rLanguages
                ),
                animated: true
            )
        case .accessDeniedPreviously:
            let message = R.string.localizable.qrScanErrorGalleryRestrictedPreviously(
                preferredLanguages: locale?.rLanguages
            )
            let title = R.string.localizable.qrScanErrorGalleryTitle(
                preferredLanguages: locale?.rLanguages
            )

            wireframe.askOpenApplicationSettings(
                with: message,
                title: title,
                from: view,
                locale: locale
            )
        default:
            break
        }
    }

    func handle(plainTextCode: String) {
        logger?.warning("Plain data recieved but not handled: \(plainTextCode)")
    }

    func handle(rawDataCode: Data) {
        logger?.warning("Raw data recieved but not handled: \(rawDataCode.base64EncodedString())")
    }

    func setup() {
        startServiceIfNeeded()
    }

    func viewWillAppear() {
        startServiceIfNeeded()
    }

    func viewDidDisappear() {
        stopServiceIfNeeded()
    }

    func uploadGallery() {
        wireframe.presentImageGallery(from: view, delegate: self)
    }
}

extension QRScannerPresenter: QRCaptureServiceDelegate {
    func qrCapture(service _: QRCaptureServiceProtocol, didSetup captureSession: AVCaptureSession) {
        DispatchQueue.main.async {
            self.view?.didReceive(session: captureSession)
        }
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didReceive data: QRCodeData) {
        switch data {
        case let .plain(plainText):
            handle(plainTextCode: plainText)
        case let .raw(rawData):
            handle(rawDataCode: rawData)
        }
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didFailure error: Error) {
        DispatchQueue.main.async {
            self.handleQRService(error: error)
        }
    }
}

extension QRScannerPresenter: ImageGalleryDelegate {
    func didCompleteImageSelection(
        from _: ImageGalleryPresentable,
        with selectedImages: [UIImage]
    ) {
        if let image = selectedImages.first {
            qrExtractionService.extract(
                from: image,
                dispatchCompletionIn: nil
            ) { [weak self] result in
                switch result {
                case let .success(code):
                    self?.handle(plainTextCode: code)
                case let .failure(error):
                    DispatchQueue.main.async {
                        self?.handleQRService(error: error)
                    }
                }
            }
        }
    }

    func didFail(in _: ImageGalleryPresentable, with error: Error) {
        DispatchQueue.main.async {
            self.handleQRService(error: error)
        }
    }
}
