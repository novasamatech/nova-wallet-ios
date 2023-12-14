import RobinHood

protocol ProxiedsUpdateViewProtocol: ControllerBackedProtocol {
    func didReceive(
        delegatedModels: [ProxyWalletView.ViewModel],
        revokedModels: [ProxyWalletView.ViewModel]
    )
    func preferredContentHeight(
        delegatedModels: [ProxyWalletView.ViewModel],
        revokedModels: [ProxyWalletView.ViewModel]
    ) -> CGFloat
}

protocol ProxiedsUpdatePresenterProtocol: AnyObject {
    func setup()
    func done()
    func showInfo()
}

protocol ProxiedsUpdateInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ProxiedsUpdateInteractorOutputProtocol: AnyObject {
    func didReceiveWalletsChanges(_ changes: [DataProviderChange<ManagedMetaAccountModel>])
    func didReceiveChainChanges(_ changes: [DataProviderChange<ChainModel>])
    func didReceiveError(_ error: ProxiedsUpdateError)
}

protocol ProxiedsUpdateWireframeProtocol: AnyObject, WebPresentable {
    func close(from view: ControllerBackedProtocol?)
}

enum ProxiedsUpdateError: Error {
    case subscription(Error)
}
