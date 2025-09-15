import Foundation
import Foundation_iOS

struct ParitySignerTxScanViewFactory {
    static func createView(
        from signingData: Data,
        accountId: AccountId,
        params: ParitySignerConfirmationParams,
        expirationTimer: CountdownTimerMediating?,
        completion: @escaping TransactionSigningClosure
    ) -> ParitySignerTxScanViewProtocol? {
        let interactor = ParitySignerTxScanInteractor(signingData: signingData, params: params, accountId: accountId)

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
            R.string(preferredLanguages: locale.rLanguages).localizable.paritySignerTxTitle(
                params.type.getName(for: locale)
            )
        }

        let message = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.paritySignerScanTitle_9_7_0(
                params.type.getName(for: locale)
            )
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
