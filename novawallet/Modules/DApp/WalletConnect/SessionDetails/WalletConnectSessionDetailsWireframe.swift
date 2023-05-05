import Foundation

final class WalletConnectSessionDetailsWireframe: WalletConnectSessionDetailsWireframeProtocol {
    func close(view: WalletConnectSessionDetailsViewProtocol?) {
        if let presentingViewController = view?.controller.presentedViewController {
            presentingViewController.dismiss(animated: false)
        }

        view?.controller.navigationController?.popViewController(animated: true)
    }

    func showNetworks(from view: WalletConnectSessionDetailsViewProtocol?, networks: [ChainModel]) {
        guard let viewController = ModalNetworksFactory.createNetworksInfoList(for: networks) else {
            return
        }

        view?.controller.present(viewController, animated: true, completion: nil)
    }
}
