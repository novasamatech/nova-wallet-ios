protocol WalletConnectViewProtocol: ControllerBackedProtocol {}

protocol WalletConnectPresenterProtocol: AnyObject {
    func setup()
    func showScan()
}

protocol WalletConnectInteractorInputProtocol: AnyObject {
    func setup()
    func connect(uri: String)
}

protocol WalletConnectInteractorOutputProtocol: AnyObject {}

protocol WalletConnectWireframeProtocol: AnyObject {
    func showScan(from view: WalletConnectViewProtocol?, delegate: URIScanDelegate)
}
