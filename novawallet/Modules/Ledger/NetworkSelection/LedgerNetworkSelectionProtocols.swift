protocol LedgerNetworkSelectionViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [ChainAccountAddViewModel])
}

protocol LedgerNetworkSelectionPresenterProtocol: AnyObject {
    func setup()
    func selectChainAccount(at index: Int)
    func cancel()
}

protocol LedgerNetworkSelectionInteractorInputProtocol: AnyObject {
    func setup()
}

protocol LedgerNetworkSelectionInteractorOutputProtocol: AnyObject {
    func didReceive(chainAccounts: [LedgerChainAccount])
}

protocol LedgerNetworkSelectionWireframeProtocol: AlertPresentable, CancelOperationPresentable {
    func showLedgerDiscovery(from view: LedgerNetworkSelectionViewProtocol?, chain: ChainModel)
    func close(view: LedgerNetworkSelectionViewProtocol?)
}
