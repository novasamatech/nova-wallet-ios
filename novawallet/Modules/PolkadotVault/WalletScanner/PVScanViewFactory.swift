import Foundation
import Foundation_iOS

struct PVScanViewFactory {
    static func createOnboardingView(with type: ParitySignerType) -> QRScannerViewProtocol? {
        createView(wireframe: PVScanWireframe(), type: type)
    }

    static func createAddAccountView(with type: ParitySignerType) -> QRScannerViewProtocol? {
        createView(wireframe: AddAccount.PVScanWireframe(), type: type)
    }

    static func createSwitchAccountView(with type: ParitySignerType) -> QRScannerViewProtocol? {
        createView(wireframe: SwitchAccount.PVScanWireframe(), type: type)
    }

    private static func createView(
        wireframe: PVScanWireframeProtocol,
        type: ParitySignerType
    ) -> QRScannerViewProtocol? {
        let processingQueue = QRCaptureService.processingQueue
        let qrService = QRCaptureService(delegate: nil, delegateQueue: processingQueue)
        let qrExtractor = QRExtractionService(processingQueue: processingQueue)

        let localizationManager = LocalizationManager.shared

        let qrExtractionError = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.paritySignerAddressScanError()
        }

        let presenter = PVScanPresenter(
            type: type,
            matcher: PVAccountScanMatcher(),
            scanWireframe: wireframe,
            baseWireframe: QRScannerWireframe(),
            qrScanService: qrService,
            qrExtractionService: qrExtractor,
            qrExtractionError: qrExtractionError,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let message = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.polkadotVaultScannerMessage(
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

        return view
    }
}
