protocol KnownNetworksListViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: KnownNetworksListViewLayout.Model)
}

protocol KnownNetworksListPresenterProtocol: AnyObject {
    func setup()
    func selectChain(at index: Int)
    func addNetworkManually()
}

protocol KnownNetworksListInteractorInputProtocol: AnyObject {
    func provideChains()
    func provideChain(with chainId: ChainModel.Id)
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
