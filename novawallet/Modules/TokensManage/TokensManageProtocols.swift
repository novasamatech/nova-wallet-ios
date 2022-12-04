import RobinHood

protocol TokensManageViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [TokensManageViewModel])
}

protocol TokensManagePresenterProtocol: AnyObject {
    func setup()
    func search(query: String)
    func performAddToken()
    func performEdit(for viewModel: TokensManageViewModel)
    func performSwitch(for viewModel: TokensManageViewModel, isOn: Bool)
}

protocol TokensManageInteractorInputProtocol: AnyObject {
    func setup()
    func save(chains: [ChainModel])
}

protocol TokensManageInteractorOutputProtocol: AnyObject {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>])
}

protocol TokensManageWireframeProtocol: AnyObject {}
