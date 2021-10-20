import Foundation

protocol NetworkDetailsViewProtocol: ControllerBackedProtocol {
    func reload(viewModel: NetworkDetailsViewModel)
}

protocol NetworkDetailsPresenterProtocol: AnyObject {
    func setup()
    func handleActionButton()
    func handleDefaultNodeInfo(at index: Int)
    func handleSelectDefaultNode(at index: Int)
    func handleAutoSelectNodesToggle(isOn: Bool)
}

protocol NetworkDetailsViewModelFactoryProtocol {
    func createViewModel(
        chainModel: ChainModel,
        autoSelectNodes: Bool,
        selectedNode: ChainNodeModel,
        locale: Locale
    ) -> NetworkDetailsViewModel
}

protocol NetworkDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func toggleAutoSelectNodes(isOn: Bool)
}

protocol NetworkDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveSelectedConnection(_ connection: ChainConnection?)
    func didReceiveAutoSelectNodes(_ auto: Bool)
}

protocol NetworkDetailsWireframeProtocol: AnyObject {
    func showAddConnection(from view: ControllerBackedProtocol?)
    func showNodeInfo(
        connectionItem: ConnectionItem,
        mode: NetworkInfoMode,
        from view: ControllerBackedProtocol?
    )
}
