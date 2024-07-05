import Operation_iOS

protocol NetworksListViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: NetworksListViewLayout.Model)
    func updateNetworks(with viewModel: NetworksListViewLayout.Model)
}

protocol NetworksListPresenterProtocol: AnyObject {
    func setup()
    func select(segment: NetworksListPresenter.NetworksType?)
    func selectChain(at index: Int)
    func addNetwork()
    func integrateOwnNetwork()
    func closeBanner()
}

protocol NetworksListInteractorInputProtocol: AnyObject {
    func provideChains()
    func setIntegrationBannerSeen()
}

protocol NetworksListInteractorOutputProtocol: AnyObject {
    func didReceiveChains(changes: [DataProviderChange<ChainModel>])
    func didReceive(
        connectionState: NetworksListPresenter.ConnectionState,
        for chainId: ChainModel.Id
    )
}

protocol NetworksListWireframeProtocol: AnyObject {
    func showNetworkDetails(
        from view: NetworksListViewProtocol?,
        with chain: ChainModel
    )
    func showAddNetwork(from view: NetworksListViewProtocol?)
    func showIntegrateOwnNetwork(from view: NetworksListViewProtocol?)
}
