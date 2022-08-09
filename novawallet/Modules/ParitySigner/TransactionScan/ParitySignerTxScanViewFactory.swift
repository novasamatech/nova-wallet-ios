import Foundation
import SoraFoundation

struct ParitySignerTxScanViewFactory {
    static func createView(
        from _: Data,
        expirationTimer: CountdownTimerMediating
    ) -> ParitySignerTxScanViewProtocol? {
        let interactor = ParitySignerTxScanInteractor()
        let wireframe = ParitySignerTxScanWireframe()

        let processingQueue = QRCaptureService.processingQueue
        let qrService = QRCaptureService(delegate: nil, delegateQueue: processingQueue)
        let qrExtractor = QRExtractionService(processingQueue: processingQueue)

        let presenter = ParitySignerTxScanPresenter(
            interactor: interactor,
            baseWireframe: QRScannerWireframe(),
            scanWireframe: wireframe,
            timer: expirationTimer,
            expirationViewModelFactory: TxExpirationViewModelFactory(),
            qrScanService: qrService,
            qrExtractionService: qrExtractor,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let title = LocalizableResource { locale in
            R.string.localizable.paritySignerTxTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.paritySignerScanTitle(preferredLanguages: locale.rLanguages)
        }

        let settings = QRScannerViewSettings(canUploadFromGallery: false, extendsUnderSafeArea: false)

        let view = ParitySignerTxScanViewController(
            title: title,
            message: message,
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            settings: settings
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
