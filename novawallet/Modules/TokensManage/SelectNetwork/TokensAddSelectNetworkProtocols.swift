import RobinHood

protocol TokensAddSelectNetworkViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [DiffableNetworkViewModel])
}

protocol TokensAddSelectNetworkPresenterProtocol: AnyObject {
    func setup()
    func selectChain(at index: Int)
}

protocol TokensAddSelectNetworkInteractorInputProtocol: AnyObject {
    func setup()
}

protocol TokensAddSelectNetworkInteractorOutputProtocol: AnyObject {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>])
}

protocol TokensAddSelectNetworkWireframeProtocol: AnyObject {
    func showTokenAdd(from view: TokensAddSelectNetworkViewProtocol?, chain: ChainModel)
}
