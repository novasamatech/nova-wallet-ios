import Operation_iOS

protocol TokensManageViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [TokensManageViewModel])
}

protocol TokensManagePresenterProtocol: AnyObject {
    func setup()
    func search(query: String)
    func performAddToken()
    func performSwitch(for viewModel: TokensManageViewModel, enabled: Bool)
}

protocol TokensManageInteractorInputProtocol: AnyObject {
    func setup()
    func save(chainAssetIds: Set<ChainAssetId>, state: AssetVisibilityState)
    func save(autoAddTokensWithBalance: Bool)
}

protocol TokensManageInteractorOutputProtocol: AnyObject {
    func didReceiveGroupStyle(_ style: AssetListGroupsStyle)
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>])
    func didReceiveVisibility(changes: [DataProviderChange<AssetVisibilityLocal>])
    func didReceiveAutoAddTokens(enabled: Bool)
    func didReceiveDefaultAssets(_ list: DefaultAssetsList)
    func didFailSave()
}

protocol TokensManageWireframeProtocol: AnyObject {
    func showAddToken(from view: TokensManageViewProtocol?)
}
