protocol WalletConnectInteractorInputProtocol: AnyObject {}

protocol WalletConnectInteractorOutputProtocol: AnyObject {
    func didReceive(error: WalletConnectTransportError)
}

protocol WalletConnectDelegateInputProtocol: AnyObject {
    func connect(uri: String, completion: @escaping (Error?) -> Void)

    func add(delegate: WalletConnectDelegateOutputProtocol)
    func remove(delegate: WalletConnectDelegateOutputProtocol)

    func getSessionsCount() -> Int

    func fetchSessions(_ completion: @escaping (Result<[WalletConnectSession], Error>) -> Void)

    func disconnect(from session: String, completion: @escaping (Error?) -> Void)
}

protocol WalletConnectDelegateOutputProtocol: AnyObject {
    func walletConnectDidChangeSessions()

    func walletConnectDidChangeChains()
}

extension WalletConnectDelegateOutputProtocol {
    func walletConnectDidChangeSessions() {}

    func walletConnectDidChangeChains() {}
}
