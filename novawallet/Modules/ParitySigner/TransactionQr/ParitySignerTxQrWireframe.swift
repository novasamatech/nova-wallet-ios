import Foundation
import SoraFoundation

final class ParitySignerTxQrWireframe: ParitySignerTxQrWireframeProtocol {
    let sharedSigningPayload: Data

    init(sharedSigningPayload: Data) {
        self.sharedSigningPayload = sharedSigningPayload
    }

    func close(view: ParitySignerTxQrViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func proceed(from view: ParitySignerTxQrViewProtocol?, timer: CountdownTimerMediating) {
        guard let scanView = ParitySignerTxScanViewFactory.createView(
            from: sharedSigningPayload,
            expirationTimer: timer
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(scanView.controller, animated: true)
    }
}
