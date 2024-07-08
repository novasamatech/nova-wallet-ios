import Foundation

final class KnownNetworksListWireframe: KnownNetworksListWireframeProtocol {
    let successAddPresenting: (wireframe: ModalAlertPresenting, view: ControllerBackedProtocol)

    init(successAddPresenting: (wireframe: ModalAlertPresenting, view: ControllerBackedProtocol)) {
        self.successAddPresenting = successAddPresenting
    }

    func showAddNetwork(
        from view: KnownNetworksListViewProtocol?,
        with knownNetwork: ChainModel?
    ) {
        guard let customNetworkView = CustomNetworkViewFactory.createNetworkAddView(
            networkToAdd: knownNetwork,
            successPresenting: successAddPresenting
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            customNetworkView.controller,
            animated: true
        )
    }
}
