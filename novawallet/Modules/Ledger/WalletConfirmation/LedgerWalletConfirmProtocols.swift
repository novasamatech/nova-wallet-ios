protocol LedgerWalletConfirmInteractorInputProtocol: AnyObject {
    func save(with walletName: String)
}

protocol LedgerWalletConfirmInteractorOutputProtocol: AnyObject {
    func didCreateWallet()
    func didReceive(error: Error)
}

protocol LedgerWalletConfirmWireframeProtocol: AlertPresentable, ErrorPresentable {
    func complete(on view: ControllerBackedProtocol?)
}
