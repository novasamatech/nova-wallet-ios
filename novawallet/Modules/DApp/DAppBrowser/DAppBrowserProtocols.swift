protocol DAppBrowserViewProtocol: ControllerBackedProtocol {}

protocol DAppBrowserPresenterProtocol: AnyObject {
    func setup()
}

protocol DAppBrowserInteractorInputProtocol: AnyObject {}

protocol DAppBrowserInteractorOutputProtocol: AnyObject {}

protocol DAppBrowserWireframeProtocol: AnyObject {}
