import Foundation

final class ParitySignerTxScanWireframe: ParitySignerTxScanWireframeProtocol {
    func complete(on view: ParitySignerTxScanViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
