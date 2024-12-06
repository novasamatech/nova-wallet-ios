import SubstrateSdk
import Operation_iOS

protocol DAppListViewProtocol: ControllerBackedProtocol {
    func didReceive(state: DAppListState)
    func didCompleteRefreshing()
    func didReceive(_ sections: [DAppListSectionViewModel])
}

protocol DAppListPresenterProtocol: AnyObject {
    func setup()
    func refresh()
    func seeAllFavorites()
    func activateAccount()
    func activateSearch()
    func activateSettings()

    func selectCategory(with id: String)
    func selectDApp(with id: String)
}

protocol DAppListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()

    func addToFavorites(
        dApp: DApp,
        at index: Int
    )

    func removeFromFavorites(dAppIdentifier: String)
}

protocol DAppListInteractorOutputProtocol: AnyObject {
    func didReceive(walletResult: Result<MetaAccountModel, Error>)
    func didReceive(dAppsResult: Result<DAppList, Error>?)
    func didReceiveFavoriteDapp(changes: [DataProviderChange<DAppFavorite>])
    func didReceiveWalletsState(hasUpdates: Bool)
}

protocol DAppListWireframeProtocol: DAppAlertPresentable,
    DAppBrowserSearchPresentable,
    ErrorPresentable,
    WebPresentable,
    WalletSwitchPresentable,
    DAppBrowserOpening {
    func showSetting(from view: DAppListViewProtocol?)
    func showFavorites(from view: DAppListViewProtocol?)
}
