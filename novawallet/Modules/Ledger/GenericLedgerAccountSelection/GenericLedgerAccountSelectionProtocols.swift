import Operation_iOS

protocol GenericLedgerAccountSelectionViewProtocol: ControllerBackedProtocol {
    func didClearAccounts()
    func didAddAccount(viewModel: LedgerAccountViewModel)
    func didReceive(networkViewModel: NetworkViewModel)
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
    func loadBalance(for chainAsset: ChainAsset, at index: UInt32)
}

protocol GenericLedgerAccountSelectionInteractorOutputProtocol: AnyObject {
    func didReceiveLedgerChain(changes: [DataProviderChange<ChainModel>])
    func didReceive(accountBalance: LedgerAccountAmount, at index: UInt32)
    func didReceive(error: GenericLedgerAccountInteractorError)
}

protocol GenericLedgerAccountSelectionWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func showWalletCreate(from view: GenericLedgerAccountSelectionViewProtocol?, index: UInt32)
}

enum GenericLedgerAccountInteractorError: Error {
    case accountBalanceFetch(Error)
}
