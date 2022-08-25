import Foundation

final class LedgerTxConfirmWireframe: LedgerTxConfirmWireframeProtocol {
    func complete(on view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
