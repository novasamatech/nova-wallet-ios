import Operation_iOS

protocol GenericLedgerAccountSelectionViewProtocol: ControllerBackedProtocol {
    func didClearAccounts()
    func didAddAccount(viewModel: LedgerAccountViewModel)
    func didStartLoading()
    func didStopLoading()
}

protocol GenericLedgerAccountSelectionPresenterProtocol: AnyObject {
    func setup()
    func selectAccount(at index: Int)
    func loadNext()
}

protocol GenericLedgerAccountSelectionInteractorInputProtocol: AnyObject {
    func setup()
    func loadAccounts(at index: UInt32, schemes: Set<GenericLedgerAddressScheme>)
}

protocol GenericLedgerAccountSelectionInteractorOutputProtocol: AnyObject {
    func didReceiveLedgerChain(changes: [DataProviderChange<ChainModel>])
    func didReceive(indexedAccount: GenericLedgerIndexedAccountModel)
}

protocol GenericLedgerAccountSelectionWireframeProtocol: AnyObject {
    func showWalletCreate(from view: GenericLedgerAccountSelectionViewProtocol?, index: UInt32)
}
