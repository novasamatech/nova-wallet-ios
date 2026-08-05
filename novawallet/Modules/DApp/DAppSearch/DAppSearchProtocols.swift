import Operation_iOS

protocol DAppSearchViewProtocol: ControllerBackedProtocol {
    func didReceive(initialQuery: String)
    func didReceive(viewModel: DAppListViewModel?)
    func didReceive(stakingBannerVisible: Bool)
}

protocol DAppSearchPresenterProtocol: AnyObject {
    func setup()
    func updateSearch(query: String)
    func selectDApp(viewModel: DAppViewModel)
    func selectCategory(with id: String?)
    func selectSearchQuery()
    func activateStaking()
    func cancel()
}

protocol DAppSearchInteractorInputProtocol: AnyObject {
    func setup()
}

protocol DAppSearchInteractorOutputProtocol: AnyObject {
    func didReceive(dAppsResult: Result<DAppList?, Error>)
    func didReceiveFavorite(changes: [DataProviderChange<DAppFavorite>])
}

protocol DAppSearchWireframeProtocol: DAppAlertPresentable, StakingRedirectPresentable {
    func close(from view: DAppSearchViewProtocol?, completion: (() -> Void)?)
}

extension DAppSearchWireframeProtocol {
    func close(from view: DAppSearchViewProtocol?) {
        close(from: view, completion: nil)
    }
}

protocol DAppSearchDelegate: AnyObject {
    func didCompleteDAppSearchResult(_ result: DAppSearchResult)
}
