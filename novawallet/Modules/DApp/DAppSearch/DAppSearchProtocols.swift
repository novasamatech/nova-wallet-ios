import RobinHood
protocol DAppSearchViewProtocol: ControllerBackedProtocol {
    func didReceive(initialQuery: String)
}

protocol DAppSearchPresenterProtocol: AnyObject {
    func setup()
    func updateSearch(query: String)
    func selectSearchQuery()
    func cancel()
}

protocol DAppSearchWireframeProtocol: AnyObject {
    func close(from view: DAppSearchViewProtocol?)
}

protocol DAppSearchDelegate: AnyObject {
    func didCompleteDAppSearchResult(_ result: DAppSearchResult)
}
