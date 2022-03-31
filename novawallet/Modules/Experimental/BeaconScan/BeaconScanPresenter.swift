import Foundation
import SoraFoundation

final class BeaconScanPresenter: QRScannerPresenter {
    let matcher: BeaconQRMatching

    weak var delegate: BeaconQRDelegate?

    private var lastHandledCode: String?

    let localizationManager: LocalizationManagerProtocol

    init(
        matcher: BeaconQRMatching,
        wireframe: QRScannerWireframeProtocol,
        delegate: BeaconQRDelegate,
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
        let message = R.string.localizable.beaconScanErrorExtractFail(preferredLanguages: locale.rLanguages)
        view?.present(message: message, animated: true)
    }

    override func handle(code: String) {
        guard lastHandledCode != code else {
            return
        }

        lastHandledCode = code

        if let connectionInfo = matcher.match(code: code) {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.didReceiveBeacon(connectionInfo: connectionInfo)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.handleFailure()
            }
        }
    }
}
