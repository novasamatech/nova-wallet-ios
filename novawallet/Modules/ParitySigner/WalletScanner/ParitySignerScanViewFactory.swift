import Foundation
import Foundation_iOS

struct ParitySignerScanViewFactory {
    static func createOnboardingView(
        with type: ParitySignerType,
        mode: ParitySignerWelcomeMode
    ) -> QRScannerViewProtocol? {
        createView(wireframe: ParitySignerScanWireframe(), type: type, mode: mode)
    }

    static func createAddAccountView(
        with type: ParitySignerType,
        mode: ParitySignerWelcomeMode
    ) -> QRScannerViewProtocol? {
        createView(wireframe: AddAccount.ParitySignerScanWireframe(), type: type, mode: mode)
    }

    static func createSwitchAccountView(
        with type: ParitySignerType,
        mode: ParitySignerWelcomeMode
    ) -> QRScannerViewProtocol? {
        createView(wireframe: SwitchAccount.ParitySignerScanWireframe(), type: type, mode: mode)
    }

    private static func createView(
        wireframe: ParitySignerScanWireframeProtocol,
        type: ParitySignerType,
        mode: ParitySignerWelcomeMode
    ) -> QRScannerViewProtocol? {
        let interactor = ParitySignerScanInterator(chainRegistry: ChainRegistryFacade.sharedRegistry)

        let processingQueue = QRCaptureService.processingQueue
        let qrService = QRCaptureService(delegate: nil, delegateQueue: processingQueue)
        let qrExtractor = QRExtractionService(processingQueue: processingQueue)

        let localizationManager = LocalizationManager.shared

        let qrExtractionError = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.paritySignerAddressScanError()
        }

        let presenter = ParitySignerScanPresenter(
            type: type,
            mode: mode,
            matcher: ParitySignerScanMatcher(),
            interactor: interactor,
            scanWireframe: wireframe,
            baseWireframe: QRScannerWireframe(),
            qrScanService: qrService,
            qrExtractionService: qrExtractor,
            qrExtractionError: qrExtractionError,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let message = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.paritySignerScanTitle_9_7_0(
                type.getName(for: locale)
            )
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
        interactor.presenter = presenter

        return view
    }
}
