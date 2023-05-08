import Foundation

final class DAppWalletAuthWireframe: DAppWalletAuthWireframeProtocol {
    func close(from view: DAppWalletAuthViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
