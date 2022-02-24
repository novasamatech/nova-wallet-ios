import SubstrateSdk

protocol DAppListViewProtocol: ControllerBackedProtocol {
    func didReceiveAccount(icon: DrawableIcon)
    func didReceive(state: DAppListState)
    func didCompleteRefreshing()
}

protocol DAppListPresenterProtocol: AnyObject {
    func setup()
    func refresh()
    func activateAccount()
    func activateSearch()

    func numberOfCategories() -> Int
    func category(at index: Int) -> String
    func selectedCategoryIndex() -> Int
    func selectCategory(at index: Int)
    func numberOfDApps() -> Int
    func dApp(at index: Int) -> DAppViewModel
    func selectDApp(at index: Int)
}

protocol DAppListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol DAppListInteractorOutputProtocol: AnyObject {
    func didReceive(accountIdResult: Result<AccountId, Error>)
    func didReceive(dAppsResult: Result<DAppList, Error>?)
}

protocol DAppListWireframeProtocol: AlertPresentable, ErrorPresentable, WebPresentable {
    func showWalletSelection(from view: DAppListViewProtocol?)
    func showSearch(from view: DAppListViewProtocol?, delegate: DAppSearchDelegate)
    func showBrowser(from view: DAppListViewProtocol?, for result: DAppSearchResult)
}
