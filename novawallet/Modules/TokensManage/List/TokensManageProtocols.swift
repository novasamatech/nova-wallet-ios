import RobinHood

protocol TokensManageViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [TokensManageViewModel])
}

protocol TokensManagePresenterProtocol: AnyObject {
    func setup()
    func search(query: String)
    func performAddToken()
    func performEdit(for viewModel: TokensManageViewModel)
    func performSwitch(for viewModel: TokensManageViewModel, enabled: Bool)
}

protocol TokensManageInteractorInputProtocol: AnyObject {
    func setup()
    func save(chainAssetIds: Set<ChainAssetId>, enabled: Bool, allChains: [ChainModel])
}

protocol TokensManageInteractorOutputProtocol: AnyObject {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>])
    func didFailChainSave()
}

protocol TokensManageWireframeProtocol: AnyObject {
    func showAddToken(from view: TokensManageViewProtocol?)
    func showEditToken(from view: TokensManageViewProtocol?, token: MultichainToken)
}
