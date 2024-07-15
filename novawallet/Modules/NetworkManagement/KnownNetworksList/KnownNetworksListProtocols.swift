protocol KnownNetworksListViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func update(with viewModel: KnownNetworksListViewLayout.Model)
}

protocol KnownNetworksListPresenterProtocol: AnyObject {
    func becameActive()
    func selectChain(at index: Int)
    func search(by query: String)
    func addNetworkManually()
}

protocol KnownNetworksListInteractorInputProtocol: AnyObject {
    func provideChains()
    func provideChain(with chainId: ChainModel.Id)
    func searchChain(by query: String)
}

protocol KnownNetworksListInteractorOutputProtocol: AnyObject {
    func didReceive(_ chains: [LightChainModel])
    func didReceive(_ chain: ChainModel)
    func didReceive(_ error: Error)
}

protocol KnownNetworksListWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showAddNetwork(
        from view: KnownNetworksListViewProtocol?,
        with knownNetwork: ChainModel?
    )
}
