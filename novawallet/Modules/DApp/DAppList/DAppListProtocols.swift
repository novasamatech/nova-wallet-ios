import SubstrateSdk

protocol DAppListViewProtocol: ControllerBackedProtocol {
    func didReceiveAccount(icon: DrawableIcon)
    func didReceive(state: DAppListState)
    func didReceiveDApps(viewModels: [DAppViewModel])
}

protocol DAppListPresenterProtocol: AnyObject {
    func setup()
    func activateAccount()
    func activateSearch()
    func filterDApps(forCategory index: Int?)
    func selectDApp(at index: Int)
}

protocol DAppListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol DAppListInteractorOutputProtocol: AnyObject {
    func didReceive(accountIdResult: Result<AccountId, Error>)
    func didReceive(dAppsResult: Result<DAppList, Error>)
}

protocol DAppListWireframeProtocol: AlertPresentable, ErrorPresentable, WebPresentable {
    func showWalletSelection(from view: DAppListViewProtocol?)
    func showSearch(from view: DAppListViewProtocol?, delegate: DAppSearchDelegate)
    func showBrowser(from view: DAppListViewProtocol?, for query: String)
}
