protocol NetworkManageNodeViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: NetworkManageNodeViewModel)
}

protocol NetworkManageNodePresenterProtocol: AnyObject {
    func setup()
}

protocol NetworkManageNodeWireframeProtocol: AnyObject {
    func dismiss(_ view: NetworkManageNodeViewProtocol?)
}
