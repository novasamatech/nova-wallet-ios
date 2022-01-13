import RobinHood
protocol DAppSearchViewProtocol: ControllerBackedProtocol {
    func didReceive(initialQuery: String)
    func didReceiveDApp(viewModels: [DAppViewModel])
}

protocol DAppSearchPresenterProtocol: AnyObject {
    func setup()
    func updateSearch(query: String)
    func selectDApp(viewModel: DAppViewModel)
    func selectSearchQuery()
}

protocol DAppSearchInteractorInputProtocol: AnyObject {
    func setup()
}

protocol DAppSearchInteractorOutputProtocol: AnyObject {
    func didReceive(dAppsResult: Result<DAppList?, Error>)
}

protocol DAppSearchWireframeProtocol: AnyObject {
    func close(from view: DAppSearchViewProtocol?)
}

protocol DAppSearchDelegate: AnyObject {
    func didCompleteDAppSearchQuery(_ query: String)
}
