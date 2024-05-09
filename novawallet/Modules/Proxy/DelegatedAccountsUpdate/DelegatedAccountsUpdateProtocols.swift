import Operation_iOS

protocol DelegatedAccountsUpdateViewProtocol: ControllerBackedProtocol {
    func didReceive(
        delegatedModels: [WalletView.ViewModel],
        revokedModels: [WalletView.ViewModel]
    )
    func preferredContentHeight(
        delegatedModels: [WalletView.ViewModel],
        revokedModels: [WalletView.ViewModel]
    ) -> CGFloat
}

protocol DelegatedAccountsUpdatePresenterProtocol: AnyObject {
    func setup()
    func done()
    func showInfo()
}

protocol DelegatedAccountsUpdateInteractorInputProtocol: AnyObject {
    func setup()
}

protocol DelegatedAccountsUpdateInteractorOutputProtocol: AnyObject {
    func didReceiveWalletsChanges(_ changes: [DataProviderChange<ManagedMetaAccountModel>])
    func didReceiveChainChanges(_ changes: [DataProviderChange<ChainModel>])
    func didReceiveError(_ error: DelegatedAccountsUpdateError)
}

protocol DelegatedAccountsUpdateWireframeProtocol: AnyObject, WebPresentable {
    func close(from view: ControllerBackedProtocol?)
}

enum DelegatedAccountsUpdateError: Error {
    case subscription(Error)
}
