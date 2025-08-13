import Foundation
import Foundation_iOS

final class ParitySignerTxQrWireframe: ParitySignerTxQrWireframeProtocol {
    let sharedSigningPayload: Data
    let params: ParitySignerConfirmationParams

    init(params: ParitySignerConfirmationParams, sharedSigningPayload: Data) {
        self.params = params
        self.sharedSigningPayload = sharedSigningPayload
    }

    func close(view: ParitySignerTxQrViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func proceed(
        from view: ParitySignerTxQrViewProtocol?,
        accountId: AccountId,
        timer: CountdownTimerMediating?,
        completion: @escaping TransactionSigningClosure
    ) {
        guard let scanView = ParitySignerTxScanViewFactory.createView(
            from: sharedSigningPayload,
            accountId: accountId,
            params: params,
            expirationTimer: timer,
            completion: completion
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(scanView.controller, animated: true)
    }
}
