import Foundation

final class DAppOperationConfirmWireframe: DAppOperationConfirmWireframeProtocol {
    func close(view: DAppOperationConfirmViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
