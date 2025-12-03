import Foundation
import Foundation_iOS

final class ParitySignerScanPresenter: QRScannerPresenter {
    let interactor: ParitySignerScanInteractorInputProtocol

    let matcher: ParitySignerScanMatcherProtocol
    let qrExtractionError: LocalizableResource<String>

    let localizationManager: LocalizationManagerProtocol

    let scanWireframe: ParitySignerScanWireframeProtocol

    let type: ParitySignerType
    let mode: ParitySignerWelcomeMode

    private var lastHandledCode: String?

    private var mutex = NSLock()

    init(
        type: ParitySignerType,
        mode: ParitySignerWelcomeMode,
        matcher: ParitySignerScanMatcherProtocol,
        interactor: ParitySignerScanInteractorInputProtocol,
        scanWireframe: ParitySignerScanWireframeProtocol,
        baseWireframe: QRScannerWireframeProtocol,
        qrScanService: QRCaptureServiceProtocol,
        qrExtractionService: QRExtractionServiceProtocol,
        qrExtractionError: LocalizableResource<String>,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.type = type
        self.mode = mode
        self.matcher = matcher
        self.interactor = interactor
        self.scanWireframe = scanWireframe
        self.qrExtractionError = qrExtractionError
        self.localizationManager = localizationManager

        super.init(
            wireframe: baseWireframe,
            qrScanService: qrScanService,
            qrExtractionService: qrExtractionService,
            logger: logger
        )
    }

    private func getLastCode() -> String? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return lastHandledCode
    }

    private func setLastCode(_ newCode: String?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        lastHandledCode = newCode
    }

    private func handleFailure() {
        let locale = localizationManager.selectedLocale
        let message = qrExtractionError.value(for: locale)
        view?.present(message: message, animated: true)
    }

    override func handle(code: String) {
        guard getLastCode() != code else {
            return
        }

        setLastCode(code)

        if let addressScan = matcher.match(code: code) {
            DispatchQueue.main.async { [weak self] in
                self?.interactor.process(addressScan: addressScan)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.handleFailure()
            }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        setLastCode(nil)
    }
}

extension ParitySignerScanPresenter: ParitySignerScanInteractorOutputProtocol {
    func didReceiveValidation(result: Result<ParitySignerAddressScan, Error>) {
        switch result {
        case let .success(addressScan):
            scanWireframe.completeScan(on: view, addressScan: addressScan, type: type, mode: mode)
        case .failure:
            handleFailure()
            setLastCode(nil)
        }
    }
}
