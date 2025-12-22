import Foundation
import Foundation_iOS

enum SecretScanViewFactory {
    static func createView(importDelegate: SecretScanImportDelegate) -> QRScannerViewController {
        let processingQueue = QRCaptureService.processingQueue
        let qrService = QRCaptureService(delegate: nil, delegateQueue: processingQueue)
        let qrExtractor = QRExtractionService(processingQueue: processingQueue)

        let localizationManager = LocalizationManager.shared

        let qrExtractionError = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonInvalidQrCode()
        }

        let presenter = SecretScanImportPresenter(
            matcher: PVAccountScanMatcher(),
            scanWireframe: SecretScanImportWireframe(delegate: importDelegate),
            baseWireframe: QRScannerWireframe(),
            qrScanService: qrService,
            qrExtractionService: qrExtractor,
            qrExtractionError: qrExtractionError,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let message = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonScanMessage()
        }

        let settings = QRScannerViewSettings(canUploadFromGallery: false, extendsUnderSafeArea: true)

        let view = QRScannerViewController(
            title: nil,
            details: nil,
            message: message,
            presenter: presenter,
            localizationManager: localizationManager,
            settings: settings
        )

        presenter.view = view

        return view
    }
}
