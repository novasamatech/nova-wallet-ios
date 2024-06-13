protocol NetworkDetailsViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: NetworkDetailsViewLayout.Model)
    func updateNodes(with viewModel: NetworkDetailsViewLayout.Section)
}

protocol NetworkDetailsPresenterProtocol: AnyObject {
    func setup()
    func setNetwork(enabled: Bool)
    func setAutoBalance(enabled: Bool)
    func addNode()
    func selectNode(at index: Int)
}

protocol NetworkDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func setSetNetworkConnection(enabled: Bool)
    func setAutoBalance(enabled: Bool)
    func selectNode(_ node: ChainNodeModel)
}

protocol NetworkDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(_ chain: ChainModel)
    func didReceive(
        _ connectionState: NetworkDetailsPresenter.ConnectionState,
        for nodeURL: String
    )
    func didReceive(_ selectedNode: ChainNodeModel)
}

protocol NetworkDetailsWireframeProtocol: AnyObject {}
