import Foundation
import Foundation_iOS

struct AddressScanViewFactory {
    static func createAnyAddressScan(
        for delegate: AddressScanDelegate,
        context: AnyObject?
    ) -> QRScannerViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.commonAddressScanTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.commonAddressScanMessage(preferredLanguages: locale.rLanguages)
        }

        let qrExtractionError = LocalizableResource { locale in
            R.string.localizable.commonAddressScanError(preferredLanguages: locale.rLanguages)
        }

        return createView(
            for: title,
            message: message,
            qrExtractionError: qrExtractionError,
            for: delegate,
            context: context
        )
    }

    static func createTransferRecipientScan(
        for delegate: AddressScanDelegate,
        context: AnyObject?
    ) -> QRScannerViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.recepientScanTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.recepientScanMessage(preferredLanguages: locale.rLanguages)
        }

        let qrExtractionError = LocalizableResource { locale in
            R.string.localizable.recepientScanError(preferredLanguages: locale.rLanguages)
        }

        return createView(
            for: title,
            message: message,
            qrExtractionError: qrExtractionError,
            for: delegate,
            context: context
        )
    }

    static func createView(
        for title: LocalizableResource<String>,
        message: LocalizableResource<String>,
        qrExtractionError: LocalizableResource<String>,
        for delegate: AddressScanDelegate,
        context: AnyObject?
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
            context: context,
            qrScanService: qrService,
            qrExtractionService: qrExtractor,
            localizationManager: localizationManager,
            qrExtractionError: qrExtractionError,
            logger: Logger.shared
        )

        let view = QRScannerViewController(
            title: title,
            details: nil,
            message: message,
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }
}
