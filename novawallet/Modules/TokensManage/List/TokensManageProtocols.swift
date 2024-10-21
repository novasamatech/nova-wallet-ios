import Operation_iOS

protocol TokensManageViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [TokensManageViewModel])
    func didReceive(viewModel: AssetsSettingsViewModel)
}

protocol TokensManagePresenterProtocol: AnyObject {
    func setup()
    func search(query: String)
    func performAddToken()
    func performEdit(for viewModel: TokensManageViewModel)
    func performSwitch(for viewModel: TokensManageViewModel, enabled: Bool)
    func performFilterChange(to value: Bool)
}

protocol TokensManageInteractorInputProtocol: AnyObject {
    func setup()
    func save(chainAssetIds: Set<ChainAssetId>, enabled: Bool, allChains: [ChainModel])
    func save(hideZeroBalances: Bool)
}

protocol TokensManageInteractorOutputProtocol: AnyObject {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>])
    func didReceive(hideZeroBalances: Bool)
    func didFailChainSave()
}

protocol TokensManageWireframeProtocol: AnyObject {
    func showAddToken(from view: TokensManageViewProtocol?)
    func showEditToken(
        from view: TokensManageViewProtocol?,
        token: MultichainToken,
        allChains: [ChainModel.Id: ChainModel]
    )
}
