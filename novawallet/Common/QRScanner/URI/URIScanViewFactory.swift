import Foundation
import SoraFoundation

struct URIScanViewFactory {
    static func createWalletConnectScan(
        for delegate: URIScanDelegate,
        context: AnyObject?
    ) -> QRScannerViewProtocol? {
        let scanTitle = LocalizableResource { locale in
            R.string.localizable.walletConnectScanMessage(preferredLanguages: locale.rLanguages)
        }

        let details = LocalizableResource { locale in
            let title = R.string.localizable.commonWalletConnectV2(preferredLanguages: locale.rLanguages)
            let icon = R.image.iconWalletConnect()?.tinted(with: R.color.colorTextPrimary()!)

            return TitleIconViewModel(title: title, icon: icon)
        }

        let qrExtractionError = LocalizableResource { locale in
            R.string.localizable.walletConnectScanError(preferredLanguages: locale.rLanguages)
        }

        return createView(
            matcher: SchemeURIMatcher(scheme: "wc"),
            viewDisplayParams: .init(topTitle: nil, details: details, scanTitle: scanTitle),
            qrExtractionError: qrExtractionError,
            delegate: delegate,
            context: context
        )
    }

    static func createView(
        matcher: URIQRMatching,
        viewDisplayParams: QRScannerViewDisplayParams,
        qrExtractionError: LocalizableResource<String>,
        delegate: URIScanDelegate,
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
            title: viewDisplayParams.topTitle,
            details: viewDisplayParams.details,
            message: viewDisplayParams.scanTitle,
            presenter: presenter,
            localizationManager: localizationManager,
            settings: .init(canUploadFromGallery: true, extendsUnderSafeArea: true)
        )

        presenter.view = view

        return view
    }
}
