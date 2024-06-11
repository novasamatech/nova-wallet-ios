protocol NetworkDetailsViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: NetworkDetailsViewLayout.Model)
    func updateNodes(with viewModel: NetworkDetailsViewLayout.Model)
}

protocol NetworkDetailsPresenterProtocol: AnyObject {
    func setup()
    func toggleEnabled()
    func toggleConnectionMode()
    func addNode()
    func selectNode(at index: Int)
}

protocol NetworkDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func toggleNetwork()
    func toggleConnectionMode()
    func selectNode(with url: String)
}

protocol NetworkDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(updatedChain: ChainModel)
    func didReceive(measuredNode: MeasuredNode)
}

protocol NetworkDetailsWireframeProtocol: AnyObject {}
