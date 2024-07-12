import Foundation

final class KnownNetworksListWireframe: KnownNetworksListWireframeProtocol {
    let successAddPresenting: (wireframe: ModalAlertPresenting, view: ControllerBackedProtocol)

    init(successAddPresenting: (wireframe: ModalAlertPresenting, view: ControllerBackedProtocol)) {
        self.successAddPresenting = successAddPresenting
    }

    func showAddNetwork(
        from view: KnownNetworksListViewProtocol?,
        with _: ChainModel?
    ) {
        guard let customNetworkView = CustomNetworkViewFactory.createNetworkAddView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            customNetworkView.controller,
            animated: true
        )
    }
}
