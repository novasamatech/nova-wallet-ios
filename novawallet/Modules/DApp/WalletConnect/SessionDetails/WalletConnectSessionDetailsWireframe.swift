import Foundation

final class WalletConnectSessionDetailsWireframe: WalletConnectSessionDetailsWireframeProtocol {
    func close(view: WalletConnectSessionDetailsViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
