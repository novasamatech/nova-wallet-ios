protocol WalletConnectSessionsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [WalletConnectSessionListViewModel])
}

protocol WalletConnectSessionsPresenterProtocol: AnyObject {
    func setup()
    func showScan()
    func showSession(at index: Int)
}

protocol WalletConnectSessionsInteractorInputProtocol: AnyObject {
    func setup()
    func connect(uri: String)
    func retrySessionsFetch()
}

protocol WalletConnectSessionsInteractorOutputProtocol: AnyObject {
    func didReceive(sessions: [WalletConnectSession])
    func didReceive(error: WalletConnectSessionsInteractorError)
}

protocol WalletConnectSessionsWireframeProtocol: WalletConnectScanPresentable, AlertPresentable,
    ErrorPresentable, CommonRetryable, WalletConnectErrorPresentable {
    func showSession(from view: WalletConnectSessionsViewProtocol?, details: WalletConnectSession)
    func close(view: WalletConnectSessionsViewProtocol?)
}
