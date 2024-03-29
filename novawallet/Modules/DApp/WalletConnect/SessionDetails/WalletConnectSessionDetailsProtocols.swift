protocol WalletConnectSessionDetailsViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: WalletConnectSessionViewModel)
}

protocol WalletConnectSessionDetailsPresenterProtocol: AnyObject {
    func setup()
    func presentNetworks()
    func disconnect()
}

protocol WalletConnectSessionDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func retrySessionUpdate()
    func disconnect()
}

protocol WalletConnectSessionDetailsInteractorOutputProtocol: AnyObject {
    func didUpdate(session: WalletConnectSession)
    func didDisconnect()
    func didReceive(error: WCSessionDetailsInteractorError)
}

protocol WalletConnectSessionDetailsWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, WalletConnectErrorPresentable {
    func close(view: WalletConnectSessionDetailsViewProtocol?)
    func showNetworks(from view: WalletConnectSessionDetailsViewProtocol?, networks: [ChainModel])
}
