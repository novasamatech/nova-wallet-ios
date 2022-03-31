import Foundation
import SoraFoundation

struct BeaconScanViewFactory {
    static func createView(
        for delegate: BeaconQRDelegate
    ) -> QRScannerViewProtocol? {
        let matcher = BeaconQRMatcher()

        let processingQueue = QRCaptureService.processingQueue
        let qrService = QRCaptureService(delegate: nil, delegateQueue: processingQueue)
        let qrExtractor = QRExtractionService(processingQueue: processingQueue)

        let wireframe = QRScannerWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = BeaconScanPresenter(
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
                R.string.localizable.beaconScanTitle(preferredLanguages: locale.rLanguages)
            },
            message: LocalizableResource { locale in
                R.string.localizable.beaconScanMessage(preferredLanguages: locale.rLanguages)
            },
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }
}
