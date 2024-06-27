import Foundation

protocol NetworkDetailsViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: NetworkDetailsViewLayout.Model)
    func updateNodes(with viewModel: NetworkDetailsViewLayout.Section)
}

protocol NetworkDetailsPresenterProtocol: AnyObject {
    func setup()
    func setNetwork(enabled: Bool)
    func setAutoBalance(enabled: Bool)
    func addNode()
    func selectNode(with id: UUID)
}

protocol NetworkDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func setSetNetworkConnection(enabled: Bool)
    func setAutoBalance(enabled: Bool)
    func selectNode(_ node: ChainNodeModel)
    func deleteNode(_ node: ChainNodeModel)
}

protocol NetworkDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(
        _ chain: ChainModel,
        filteredNodes: Set<ChainNodeModel>
    )
    func didReceive(
        _ connectionState: NetworkDetailsPresenter.ConnectionState,
        for nodeURL: String,
        selected: Bool
    )
    func didReceive(_ error: Error)
}

protocol NetworkDetailsWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showAddNode(
        from view: NetworkDetailsViewProtocol?,
        chainId: ChainModel.Id
    )
    func showEditNode(
        from view: NetworkDetailsViewProtocol?,
        node: ChainNodeModel,
        chainId: ChainModel.Id
    )
    func showManageNode(
        from view: NetworkDetailsViewProtocol?,
        node: ChainNodeModel,
        onNodeEdit: @escaping () -> Void,
        onNodeDelete: @escaping () -> Void
    )
}
