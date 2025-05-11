protocol NavigationRootViewProtocol: ControllerBackedProtocol {
    func didReceive(walletSwitchViewModel: WalletSwitchViewModel)
    func didReceive(walletConnectSessions: Int)
}

protocol NavigationRootPresenterProtocol: AnyObject {
    func setup()
    func activateSettings()
    func activateWalletSelection()
    func activateWalletConnect()
}

protocol NavigationRootInteractorInputProtocol: AnyObject {
    func setup()
    func connectWalletConnect(uri: String)
    func retryFetchWalletConnectSessionsCount()
}

protocol NavigationRootInteractorOutputProtocol: AnyObject {
    func didReceive(wallet: MetaAccountModel)
    func didReceiveWalletConnect(sessionsCount: Int)
    func didReceiveWalletConnect(error: WalletConnectSessionsError)
    func didReceiveWalletsState(hasUpdates: Bool)
}

protocol NavigationRootWireframeProtocol: WalletSwitchPresentable,
    AlertPresentable,
    CommonRetryable,
    WalletConnectScanPresentable,
    WalletConnectErrorPresentable {
    func showWalletConnect(from view: NavigationRootViewProtocol?)
    func showSettings(from view: NavigationRootViewProtocol?)
}

typealias WalletConnectSessionsError = WalletConnectSessionsInteractorError
