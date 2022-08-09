import Foundation
import SoraFoundation

final class ParitySignerTxScanPresenter: QRScannerPresenter {
    let interactor: ParitySignerTxScanInteractorInputProtocol

    let timer: CountdownTimerMediating
    let expirationViewModelFactory: ExpirationViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    var scanView: ParitySignerTxScanViewProtocol? { view as? ParitySignerTxScanViewProtocol }
    var scanWireframe: ParitySignerTxScanWireframeProtocol

    init(
        interactor: ParitySignerTxScanInteractorInputProtocol,
        baseWireframe: QRScannerWireframeProtocol,
        scanWireframe: ParitySignerTxScanWireframeProtocol,
        timer: CountdownTimerMediating,
        expirationViewModelFactory: ExpirationViewModelFactoryProtocol,
        qrScanService: QRCaptureServiceProtocol,
        qrExtractionService: QRExtractionServiceProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.scanWireframe = scanWireframe
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
}

extension ParitySignerTxScanPresenter: ParitySignerTxScanInteractorOutputProtocol {}

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
