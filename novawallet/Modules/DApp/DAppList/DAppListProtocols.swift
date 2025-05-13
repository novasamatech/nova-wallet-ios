import SubstrateSdk
import Operation_iOS

protocol DAppListViewProtocol: ControllerBackedProtocol {
    func didCompleteRefreshing()
    func didReceive(_ sections: [DAppListSectionViewModel])
}

protocol DAppListPresenterProtocol: AnyObject {
    func setup()
    func refresh()
    func seeAllFavorites()
    func activateSearch()
    func activateSettings()

    func selectCategory(with id: String)
    func selectDApp(with id: String)
}

protocol DAppListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol DAppListInteractorOutputProtocol: AnyObject {
    func didReceive(dAppsResult: Result<DAppList, Error>?)
    func didReceiveFavoriteDapp(changes: [DataProviderChange<DAppFavorite>])
}

protocol DAppListWireframeProtocol: DAppAlertPresentable,
    DAppBrowserSearchPresentable,
    ErrorPresentable,
    WebPresentable,
    BrowserOpening {
    func showSetting(from view: DAppListViewProtocol?)
    func showFavorites(from view: DAppListViewProtocol?)
}
