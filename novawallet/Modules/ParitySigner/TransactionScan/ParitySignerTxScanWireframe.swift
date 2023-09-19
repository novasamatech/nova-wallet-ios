import Foundation

final class ParitySignerTxScanWireframe: ParitySignerTxScanWireframeProtocol {
    func complete(on view: ParitySignerTxScanViewProtocol?, completionClosure: @escaping () -> Void) {
        view?.controller.dismiss(animated: true, completion: completionClosure)
    }
}
