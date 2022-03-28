import Foundation
import SoraFoundation

final class TransferScanPresenter: QRScannerPresenter {
    let matcher: AddressQRMatching

    weak var delegate: TransferScanDelegate?

    private var lastHandledCode: String?

    let localizationManager: LocalizationManagerProtocol

    init(
        matcher: AddressQRMatching,
        wireframe: QRScannerWireframeProtocol,
        delegate: TransferScanDelegate,
        qrScanService: QRCaptureServiceProtocol,
        qrExtractionService: QRExtractionServiceProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.matcher = matcher
        self.delegate = delegate
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
        let message = R.string.localizable.recepientScanError(preferredLanguages: locale.rLanguages)
        view?.present(message: message, animated: true)
    }

    override func handle(code: String) {
        guard lastHandledCode != code else {
            return
        }

        lastHandledCode = code

        if let address = matcher.match(code: code) {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.transferScanDidReceiveRecepient(address: address)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.handleFailure()
            }
        }
    }
}
