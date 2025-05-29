import Operation_iOS

protocol GenericLedgerAccountSelectionViewProtocol: ControllerBackedProtocol {
    func didClearAccounts()
    func didAddAccount(viewModel: GenericLedgerAccountViewModel)
    func didStartLoading()
    func didStopLoading()
}

protocol GenericLedgerAccountSelectionPresenterProtocol: AnyObject {
    func setup()
    func selectAccount(in section: Int)
    func selectAddress(in section: Int, at index: Int)
    func loadNext()
}

protocol GenericLedgerAccountSelectionInteractorInputProtocol: AnyObject {
    func setup()
    func loadAccounts(at index: UInt32, schemes: Set<HardwareWalletAddressScheme>)
}

protocol GenericLedgerAccountSelectionInteractorOutputProtocol: AnyObject {
    func didReceiveLedgerChain(changes: [DataProviderChange<ChainModel>])
    func didReceive(account: GenericLedgerAccountModel)
    func didReceive(error: GenericLedgerAccountInteractorError)
}

protocol GenericLedgerAccountSelectionWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, AddressOptionsPresentable {
    func showWalletCreate(from view: GenericLedgerAccountSelectionViewProtocol?, index: UInt32)
}

enum GenericLedgerAccountInteractorError {
    case accountFetchFailed(Error)
}
