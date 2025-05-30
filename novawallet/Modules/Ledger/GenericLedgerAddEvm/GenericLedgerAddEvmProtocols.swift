protocol GenericLedgerAddEvmInteractorInputProtocol: AnyObject {
    func setup()
    func loadAccounts(at index: UInt32)
    func confirm()
}

protocol GenericLedgerAddEvmInteractorOutputProtocol: AnyObject {
    func didReceive(account: GenericLedgerAccountModel)
    func didUpdateWallet()
    func didReceive(error: GenericLedgerAddEvmInteractorError)
}

protocol GenericLedgerAddEvmWireframeProtocol: AnyObject {}

enum GenericLedgerAddEvmInteractorError: Error {
    case accountFailed(Error)
    case updateFailed(Error)
}
