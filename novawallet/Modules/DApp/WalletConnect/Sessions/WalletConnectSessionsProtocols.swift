protocol WalletConnectSessionsViewProtocol: ControllerBackedProtocol {}

protocol WalletConnectSessionsPresenterProtocol: AnyObject {
    func setup()
    func showScan()
}

protocol WalletConnectSessionsInteractorInputProtocol: AnyObject {
    func setup()
    func connect(uri: String)
}

protocol WalletConnectSessionsInteractorOutputProtocol: AnyObject {}

protocol WalletConnectSessionsWireframeProtocol: WalletConnectScanPresentable {}
