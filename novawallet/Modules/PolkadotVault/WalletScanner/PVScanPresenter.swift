import Foundation
import Foundation_iOS

final class PVScanPresenter: QRScannerPresenter {
    let matcher: PVScanMatcherProtocol
    let qrExtractionError: LocalizableResource<String>

    let localizationManager: LocalizationManagerProtocol

    let scanWireframe: PVScanWireframeProtocol

    let type: ParitySignerType

    private var lastHandledCode: String?

    private var mutex = NSLock()

    init(
        type: ParitySignerType,
        matcher: PVScanMatcherProtocol,
        scanWireframe: PVScanWireframeProtocol,
        baseWireframe: QRScannerWireframeProtocol,
        qrScanService: QRCaptureServiceProtocol,
        qrExtractionService: QRExtractionServiceProtocol,
        qrExtractionError: LocalizableResource<String>,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.type = type
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

        if let accountScan = matcher.match(code: code) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                scanWireframe.completeScan(
                    on: view,
                    account: accountScan,
                    type: type
                )
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.handleFailure()
                self?.setLastCode(nil)
            }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        setLastCode(nil)
    }
}
