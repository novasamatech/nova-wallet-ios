protocol DAppSearchViewProtocol: ControllerBackedProtocol {}

protocol DAppSearchPresenterProtocol: AnyObject {
    func setup()
    func activateBrowser(for input: String)
}

protocol DAppSearchInteractorInputProtocol: AnyObject {}

protocol DAppSearchInteractorOutputProtocol: AnyObject {}

protocol DAppSearchWireframeProtocol: AnyObject {
    func showBrowser(from view: DAppSearchViewProtocol?, input: String)
}
