import Foundation
import SoraFoundation

struct ParitySignerScanViewFactory {
    static func createView() -> QRScannerViewProtocol? {
        let processingQueue = QRCaptureService.processingQueue
        let qrService = QRCaptureService(delegate: nil, delegateQueue: processingQueue)
        let qrExtractor = QRExtractionService(processingQueue: processingQueue)

        let localizationManager = LocalizationManager.shared

        let qrExtractionError = LocalizableResource { locale in
            R.string.localizable.paritySignerAddressScanError(preferredLanguages: locale.rLanguages)
        }

        let presenter = ParitySignerScanPresenter(
            matcher: ParitySignerScanMatcher(),
            scanWireframe: ParitySignerScanWireframe(),
            baseWireframe: QRScannerWireframe(),
            qrScanService: qrService,
            qrExtractionService: qrExtractor,
            qrExtractionError: qrExtractionError,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let message = LocalizableResource { locale in
            R.string.localizable.paritySignerScanTitle(preferredLanguages: locale.rLanguages)
        }

        let settings = QRScannerViewSettings(canUploadFromGallery: false, extendsUnderSafeArea: true)

        let view = QRScannerViewController(
            title: nil,
            message: message,
            presenter: presenter,
            localizationManager: localizationManager,
            settings: settings
        )

        presenter.view = view

        return view
    }
}
