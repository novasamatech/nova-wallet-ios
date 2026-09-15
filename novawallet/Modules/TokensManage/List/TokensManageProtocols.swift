import Operation_iOS

protocol TokensManageViewProtocol: ControllerBackedProtocol {
    func didReceive(sections: [TokensManageSection], animated: Bool)
    func didReceive(autoAddTokens: Bool)
}

protocol TokensManagePresenterProtocol: AnyObject {
    func setup()
    func search(query: String)
    func performAddToken()
    func performAutoAddChange(to isOn: Bool)
    func performExpand(for viewModel: TokensManageRootViewModel)
    func performSwitch(for root: TokensManageRootViewModel, isOn: Bool)
    func performSwitch(for child: TokensManageChildViewModel, isOn: Bool)
}

protocol TokensManageInteractorInputProtocol: AnyObject {
    func setup()
    func save(chainAssetIds: Set<ChainAssetId>, isVisible: Bool)
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
