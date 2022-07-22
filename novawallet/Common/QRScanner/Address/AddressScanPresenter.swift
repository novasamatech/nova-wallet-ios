import Foundation
import SoraFoundation

final class TransferScanPresenter: QRScannerPresenter {
    let matcher: AddressQRMatching
    let context: AnyObject?
    let qrExtractionError: LocalizableResource<String>

    weak var delegate: AddressScanDelegate?

    private var lastHandledCode: String?

    let localizationManager: LocalizationManagerProtocol

    init(
        matcher: AddressQRMatching,
        wireframe: QRScannerWireframeProtocol,
        delegate: AddressScanDelegate,
        context: AnyObject?,
        qrScanService: QRCaptureServiceProtocol,
        qrExtractionService: QRExtractionServiceProtocol,
        localizationManager: LocalizationManagerProtocol,
        qrExtractionError: LocalizableResource<String>,
        logger: LoggerProtocol? = nil
    ) {
        self.matcher = matcher
        self.delegate = delegate
        self.context = context
        self.qrExtractionError = qrExtractionError
        self.localizationManager = localizationManager

        super.init(
            wireframe: wireframe,
            qrScanService: qrScanService,
            qrExtractionService: qrExtractionService,
            logger: logger
        )
    }

    private func handleFailure() {
        let locale = localizationManager.selectedLocale
        let message = qrExtractionError.value(for: locale)
        view?.present(message: message, animated: true)
    }

    override func handle(code: String) {
        guard lastHandledCode != code else {
            return
        }

        lastHandledCode = code

        if let address = matcher.match(code: code) {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.addressScanDidReceiveRecepient(address: address, context: self?.context)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.handleFailure()
            }
        }
    }
}
