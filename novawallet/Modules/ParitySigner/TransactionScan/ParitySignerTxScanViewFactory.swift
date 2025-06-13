import Foundation
import Foundation_iOS

struct ParitySignerTxScanViewFactory {
    static func createView(
        from signingData: Data,
        params: ParitySignerConfirmationParams,
        verificationModel: ParitySignerSignatureVerificationModel,
        expirationTimer: CountdownTimerMediating?,
        completion: @escaping TransactionSigningClosure
    ) -> ParitySignerTxScanViewProtocol? {
        let interactor = ParitySignerTxScanInteractor(
            signingData: signingData,
            params: params,
            verificationModel: verificationModel,
            verificationWrapper: SignatureVerificationWrapper()
        )

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
            R.string.localizable.paritySignerTxTitle(
                params.type.getName(for: locale),
                preferredLanguages: locale.rLanguages
            )
        }

        let message = LocalizableResource { locale in
            R.string.localizable.paritySignerScanTitle_9_7_0(
                params.type.getName(for: locale),
                preferredLanguages: locale.rLanguages
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
