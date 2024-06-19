protocol NetworkManageNodeViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: NetworkManageNodeViewModel)
}

protocol NetworkManageNodePresenterProtocol: AnyObject {
    func setup()
}
