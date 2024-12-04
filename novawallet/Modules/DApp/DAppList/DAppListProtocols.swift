import SubstrateSdk
import Operation_iOS

protocol DAppListViewProtocol: ControllerBackedProtocol {
    func didReceive(state: DAppListState)
    func didCompleteRefreshing()
    func didReceive(_ sections: [DAppListSection])
}

protocol DAppListPresenterProtocol: AnyObject {
    func setup()
    func refresh()
    func activateAccount()
    func activateSearch()
    func activateSettings()

    func selectCategory(with id: String)
    func selectDApp(with id: String)
}

protocol DAppListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func addToFavorites(dApp: DApp)
    func removeFromFavorites(dAppIdentifier: String)
}

protocol DAppListInteractorOutputProtocol: AnyObject {
    func didReceive(walletResult: Result<MetaAccountModel, Error>)
    func didReceive(dAppsResult: Result<DAppList, Error>?)
    func didReceiveFavoriteDapp(changes: [DataProviderChange<DAppFavorite>])
    func didReceiveWalletsState(hasUpdates: Bool)
}

protocol DAppListWireframeProtocol: DAppAlertPresentable,
    ErrorPresentable,
    WebPresentable,
    WalletSwitchPresentable,
    DAppBrowserOpening {
    func showSearch(
        from view: DAppListViewProtocol?,
        delegate: DAppSearchDelegate
    )
    func showSetting(from view: DAppListViewProtocol?)
}
