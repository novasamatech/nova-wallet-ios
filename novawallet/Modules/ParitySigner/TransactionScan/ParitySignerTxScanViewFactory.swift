import Foundation
import SoraFoundation

struct ParitySignerTxScanViewFactory {
    static func createView(
        from signingData: Data,
        accountId: AccountId,
        expirationTimer: CountdownTimerMediating,
        completion: @escaping TransactionSigningClosure
    ) -> ParitySignerTxScanViewProtocol? {
        let interactor = ParitySignerTxScanInteractor(signingData: signingData, accountId: accountId)

        let wireframe = ParitySignerTxScanWireframe()

        let processingQueue = QRCaptureService.processingQueue
        let qrService = QRCaptureService(delegate: nil, delegateQueue: processingQueue)
        let qrExtractor = QRExtractionService(processingQueue: processingQueue)

        let presenter = ParitySignerTxScanPresenter(
            interactor: interactor,
            baseWireframe: QRScannerWireframe(),
            scanWireframe: wireframe,
            completion: completion,
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
            details: nil,
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
