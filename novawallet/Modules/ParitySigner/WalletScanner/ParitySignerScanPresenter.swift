import Foundation
import SoraFoundation

final class ParitySignerScanPresenter: QRScannerPresenter {
    let matcher: ParitySignerScanMatcherProtocol
    let qrExtractionError: LocalizableResource<String>

    let localizationManager: LocalizationManagerProtocol

    let scanWireframe: ParitySignerScanWireframeProtocol

    private var lastHandledCode: String?

    private var mutex = NSLock()

    init(
        matcher: ParitySignerScanMatcherProtocol,
        scanWireframe: ParitySignerScanWireframeProtocol,
        baseWireframe: QRScannerWireframeProtocol,
        qrScanService: QRCaptureServiceProtocol,
        qrExtractionService: QRExtractionServiceProtocol,
        qrExtractionError: LocalizableResource<String>,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.matcher = matcher
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
                self?.scanWireframe.completeScan(on: self?.view, addressScan: addressScan)
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
