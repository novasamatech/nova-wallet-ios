import Operation_iOS

protocol GenericLedgerWalletInteractorInputProtocol: AnyObject {
    func setup()
    func fetchAccount()
    func confirmAccount()
    func cancelRequest()
}

protocol GenericLedgerWalletInteractorOutputProtocol: AnyObject {
    func didReceive(account: LedgerAccount)
    func didReceiveAccountConfirmation()
    func didReceiveChains(changes: [DataProviderChange<ChainModel>])
    func didReceive(error: GenericWalletConfirmInteractorError)
}

protocol GenericLedgerWalletWireframeProtocol: AlertPresentable, ErrorPresentable, AddressOptionsPresentable {}
