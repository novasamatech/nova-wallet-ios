protocol TokenManageSingleViewProtocol: ControllerBackedProtocol {
    func didReceiveNetwork(viewModels: [TokenManageNetworkViewModel])
    func didReceiveTokenManage(viewModel: TokenManageViewModel)
}

protocol TokenManageSinglePresenterProtocol: AnyObject {
    func setup()
    func performSwitch(for viewModel: TokenManageNetworkViewModel, enabled: Bool)
}
