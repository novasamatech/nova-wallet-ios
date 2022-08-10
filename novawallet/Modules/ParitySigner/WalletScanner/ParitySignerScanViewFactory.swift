import Foundation
import SoraFoundation

struct ParitySignerScanViewFactory {
    static func createOnboardingView() -> QRScannerViewProtocol? {
        createView(wireframe: ParitySignerScanWireframe())
    }

    static func createAddAccountView() -> QRScannerViewProtocol? {
        createView(wireframe: AddAccount.ParitySignerScanWireframe())
    }

    static func createSwitchAccountView() -> QRScannerViewProtocol? {
        createView(wireframe: SwitchAccount.ParitySignerScanWireframe())
    }

    private static func createView(wireframe: ParitySignerScanWireframeProtocol) -> QRScannerViewProtocol? {
        let interactor = ParitySignerScanInterator(chainRegistry: ChainRegistryFacade.sharedRegistry)

        let processingQueue = QRCaptureService.processingQueue
        let qrService = QRCaptureService(delegate: nil, delegateQueue: processingQueue)
        let qrExtractor = QRExtractionService(processingQueue: processingQueue)

        let localizationManager = LocalizationManager.shared

        let qrExtractionError = LocalizableResource { locale in
            R.string.localizable.paritySignerAddressScanError(preferredLanguages: locale.rLanguages)
        }

        let presenter = ParitySignerScanPresenter(
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
        interactor.presenter = presenter

        return view
    }
}
