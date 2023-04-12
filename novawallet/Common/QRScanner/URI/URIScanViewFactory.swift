import Foundation
import SoraFoundation

struct URIScanViewFactory {
    static func createScan(
        for delegate: URIScanDelegate,
        context: AnyObject?
    ) -> QRScannerViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.commonWalletConnect(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.walletConnectScanMessage(preferredLanguages: locale.rLanguages)
        }

        let qrExtractionError = LocalizableResource { locale in
            R.string.localizable.walletConnectScanError(preferredLanguages: locale.rLanguages)
        }

        return createView(
            matcher: SchemeURIMatcher(scheme: "wc"),
            title: title,
            message: message,
            qrExtractionError: qrExtractionError,
            for: delegate,
            context: context
        )
    }

    static func createView(
        matcher: URIQRMatching,
        title: LocalizableResource<String>,
        message: LocalizableResource<String>,
        qrExtractionError: LocalizableResource<String>,
        for delegate: URIScanDelegate,
        context: AnyObject?
    ) -> QRScannerViewProtocol? {
        let processingQueue = QRCaptureService.processingQueue
        let qrService = QRCaptureService(delegate: nil, delegateQueue: processingQueue)
        let qrExtractor = QRExtractionService(processingQueue: processingQueue)

        let wireframe = QRScannerWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = URIScanPresenter(
            matcher: matcher,
            wireframe: wireframe,
            delegate: delegate,
            context: context,
            qrScanService: qrService,
            qrExtractionService: qrExtractor,
            localizationManager: localizationManager,
            qrExtractionError: qrExtractionError,
            logger: Logger.shared
        )

        let view = QRScannerViewController(
            title: title,
            message: message,
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }
}
