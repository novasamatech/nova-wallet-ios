protocol WalletConnectInteractorInputProtocol: AnyObject {}

protocol WalletConnectInteractorOutputProtocol: AnyObject {}

protocol WalletConnectDelegateInputProtocol: AnyObject {
    func connect(uri: String)

    func add(delegate: WalletConnectDelegateOutputProtocol)
    func remove(delegate: WalletConnectDelegateOutputProtocol)

    func getSessionsCount() -> Int
}

protocol WalletConnectDelegateOutputProtocol: AnyObject {
    func walletConnectDidChangeSessions()
}
