import Foundation

final class NotificationWalletListWireframe: NotificationWalletListWireframeProtocol {
    let completion: ([Web3Alert.LocalWallet]) -> Void

    init(completion: @escaping ([Web3Alert.LocalWallet]) -> Void) {
        self.completion = completion
    }

    func complete(
        from view: ControllerBackedProtocol?,
        selectedWallets: [Web3Alert.LocalWallet]
    ) {
        completion(selectedWallets)
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
