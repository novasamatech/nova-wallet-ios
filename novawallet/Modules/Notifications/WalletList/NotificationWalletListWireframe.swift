import Foundation

final class NotificationWalletListWireframe: NotificationWalletListWireframeProtocol {
    let completion: ([Web3AlertWallet]) -> Void

    init(completion: @escaping ([Web3AlertWallet]) -> Void) {
        self.completion = completion
    }

    func complete(
        from view: ControllerBackedProtocol?,
        selectedWallets: [Web3AlertWallet]
    ) {
        completion(selectedWallets)
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
