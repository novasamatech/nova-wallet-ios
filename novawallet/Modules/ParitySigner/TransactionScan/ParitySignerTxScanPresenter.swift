import Foundation
import SoraFoundation
import IrohaCrypto

final class ParitySignerTxScanPresenter: QRScannerPresenter {
    let interactor: ParitySignerTxScanInteractorInputProtocol

    let timer: CountdownTimerMediating
    let expirationViewModelFactory: ExpirationViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol
    let completion: TransactionSigningClosure

    var scanView: ParitySignerTxScanViewProtocol? { view as? ParitySignerTxScanViewProtocol }
    var scanWireframe: ParitySignerTxScanWireframeProtocol

    private var lastHandledCode: String?

    init(
        interactor: ParitySignerTxScanInteractorInputProtocol,
        baseWireframe: QRScannerWireframeProtocol,
        scanWireframe: ParitySignerTxScanWireframeProtocol,
        completion: @escaping TransactionSigningClosure,
        timer: CountdownTimerMediating,
        expirationViewModelFactory: ExpirationViewModelFactoryProtocol,
        qrScanService: QRCaptureServiceProtocol,
        qrExtractionService: QRExtractionServiceProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.scanWireframe = scanWireframe
        self.completion = completion
        self.timer = timer
        self.expirationViewModelFactory = expirationViewModelFactory
        self.localizationManager = localizationManager

        super.init(
            wireframe: baseWireframe,
            qrScanService: qrScanService,
            qrExtractionService: qrExtractionService,
            logger: logger
        )
    }

    private func handle(error: Error) {
        _ = scanWireframe.present(error: error, from: view, locale: selectedLocale)
        logger?.error("Did receive error: \(error)")
    }

    private func updateTimerViewModel() {
        do {
            let viewModel = try expirationViewModelFactory.createViewModel(from: timer.remainedInterval)
            scanView?.didReceiveExpiration(viewModel: viewModel)
        } catch {
            handle(error: error)
        }
    }

    private func subscribeTimer() {
        timer.addObserver(self)
    }

    override func setup() {
        super.setup()

        subscribeTimer()
        updateTimerViewModel()
    }

    override func handle(code: String) {
        guard lastHandledCode != code else {
            return
        }

        lastHandledCode = code

        DispatchQueue.main.async { [weak self] in
            self?.interactor.process(scannedSignature: code)
        }
    }
}

extension ParitySignerTxScanPresenter: ParitySignerTxScanInteractorOutputProtocol {
    func didReceiveSignature(_ signature: IRSignatureProtocol) {
        scanWireframe.complete(on: scanView)
        completion(.success(signature))
    }

    func didReceiveError(_: Error) {
        let locale = localizationManager.selectedLocale
        let message = R.string.localizable.paritySignerTxScanInvalid(preferredLanguages: locale.rLanguages)
        view?.present(message: message, animated: true)
    }
}

extension ParitySignerTxScanPresenter: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {
        updateTimerViewModel()
    }

    func didCountdown(remainedInterval _: TimeInterval) {
        updateTimerViewModel()
    }

    func didStop(with _: TimeInterval) {
        updateTimerViewModel()
    }
}

extension ParitySignerTxScanPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateTimerViewModel()
        }
    }
}
