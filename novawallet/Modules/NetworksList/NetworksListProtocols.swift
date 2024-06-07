import RobinHood

protocol NetworksListViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: NetworksListViewLayout.Model)
    func updateNetworks(with viewModel: NetworksListViewLayout.Model)
}

protocol NetworksListPresenterProtocol: AnyObject {
    func setup()
    func select(segment: NetworksListPresenter.NetworksType?)
    func selectChain(at index: Int)
}

protocol NetworksListInteractorInputProtocol: AnyObject {
    func provideChains()
}

protocol NetworksListInteractorOutputProtocol: AnyObject {
    func didReceiveChains(changes: [DataProviderChange<ChainModel>])
    func didReceive(
        connectionState: NetworksListPresenter.ConnectionState,
        for chainId: ChainModel.Id
    )
}

protocol NetworksListWireframeProtocol: AnyObject {}
