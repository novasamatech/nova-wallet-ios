import Operation_iOS

protocol GenericLedgerAccountSelectionViewProtocol: AnyObject {}

protocol GenericLedgerAccountSelectionPresenterProtocol: AnyObject {
    func setup()
}

protocol GenericLedgerAccountSelectionInteractorInputProtocol: AnyObject {
    func setup()
    func loadBalance(for chainAsset: ChainAsset, at index: UInt32)
}

protocol GenericLedgerAccountSelectionInteractorOutputProtocol: AnyObject {
    func didReceiveLedgerChain(changes: [DataProviderChange<ChainModel>])
    func didReceive(accountBalance: LedgerAccountAmount, at index: UInt32)
    func didReceive(error: GenericLedgerAccountSelectionInteractorError)
}

protocol GenericLedgerAccountSelectionWireframeProtocol: AnyObject {}

enum GenericLedgerAccountSelectionInteractorError: Error {
    case accountBalanceFetch(Error)
}
