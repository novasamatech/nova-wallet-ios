protocol DAppSearchViewProtocol: ControllerBackedProtocol {
    func didReceive(initialQuery: String)
}

protocol DAppSearchPresenterProtocol: AnyObject {
    func setup()
    func activateSearch(for input: String)
}

protocol DAppSearchInteractorInputProtocol: AnyObject {}

protocol DAppSearchInteractorOutputProtocol: AnyObject {}

protocol DAppSearchWireframeProtocol: AnyObject {
    func close(from view: DAppSearchViewProtocol?)
}

protocol DAppSearchDelegate: AnyObject {
    func didCompleteDAppSearchQuery(_ query: String)
}
