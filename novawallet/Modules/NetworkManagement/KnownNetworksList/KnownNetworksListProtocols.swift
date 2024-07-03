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
}

protocol KnownNetworksListInteractorOutputProtocol: AnyObject {
    func didReceive(chains: [ChainModel])
}

protocol KnownNetworksListWireframeProtocol: AnyObject {
    func showAddNetwork(
        from view: KnownNetworksListViewProtocol?,
        with knownNetwork: ChainModel?
    )
}
