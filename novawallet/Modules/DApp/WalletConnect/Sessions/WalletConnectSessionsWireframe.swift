import Foundation

final class WalletConnectSessionsWireframe: WalletConnectSessionsWireframeProtocol {
    func showSession(from _: WalletConnectSessionsViewProtocol?, details _: WalletConnectSession) {
        // TODO: Present session details
    }

    func close(view: WalletConnectSessionsViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
