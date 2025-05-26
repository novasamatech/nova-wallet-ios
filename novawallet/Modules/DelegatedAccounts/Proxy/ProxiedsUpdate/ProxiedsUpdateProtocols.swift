import Operation_iOS

protocol ProxiedsUpdateViewProtocol: ControllerBackedProtocol {
    func didReceive(
        delegatedModels: [WalletView.ViewModel],
        revokedModels: [WalletView.ViewModel]
    )
    func preferredContentHeight(
        delegatedModelsCount: Int,
        revokedModelsCount: Int
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
    func close(from view: ControllerBackedProtocol?, andPresent url: URL)
}

enum ProxiedsUpdateError: Error {
    case subscription(Error)
}
