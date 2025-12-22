import Foundation
import Foundation_iOS

final class SecretScanImportPresenter: QRScannerPresenter {
    let matcher: PVScanMatcherProtocol
    let qrExtractionError: LocalizableResource<String>

    let localizationManager: LocalizationManagerProtocol

    let scanWireframe: SecretScanImportWireframeProtocol

    private var lastHandledCode: String?

    private var mutex = NSLock()

    init(
        matcher: PVScanMatcherProtocol,
        scanWireframe: SecretScanImportWireframeProtocol,
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

    override func handle(code: String) {
        guard getLastCode() != code else { return }

        setLastCode(code)

        if let accountScan = matcher.match(code: code),
           case let .private(_, secret) = accountScan {
            DispatchQueue.main.async { [weak self] in
                self?.scanWireframe.completeAndPop(
                    on: self?.view,
                    scan: secret.secret
                )
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

// MARK: - Private

private extension SecretScanImportPresenter {
    func getLastCode() -> String? {
        mutex.lock()
        defer { mutex.unlock() }

        return lastHandledCode
    }

    func setLastCode(_ newCode: String?) {
        mutex.lock()
        defer { mutex.unlock() }

        lastHandledCode = newCode
    }

    func handleFailure() {
        let locale = localizationManager.selectedLocale
        let message = qrExtractionError.value(for: locale)
        view?.present(message: message, animated: true)
    }
}
