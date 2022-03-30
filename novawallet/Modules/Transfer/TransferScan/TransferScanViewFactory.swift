import Foundation
import SoraFoundation

struct TransferScanViewFactory {
    static func createView(
        for delegate: TransferScanDelegate
    ) -> QRScannerViewProtocol? {
        let matcher = AddressQRMatcher()

        let processingQueue = QRCaptureService.processingQueue
        let qrService = QRCaptureService(delegate: nil, delegateQueue: processingQueue)
        let qrExtractor = QRExtractionService(processingQueue: processingQueue)

        let wireframe = QRScannerWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = TransferScanPresenter(
            matcher: matcher,
            wireframe: wireframe,
            delegate: delegate,
            qrScanService: qrService,
            qrExtractionService: qrExtractor,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = QRScannerViewController(
            title: LocalizableResource { locale in
                R.string.localizable.recepientScanTitle(preferredLanguages: locale.rLanguages)
            },
            message: LocalizableResource { locale in
                R.string.localizable.recepientScanMessage(preferredLanguages: locale.rLanguages)
            },
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }
}
