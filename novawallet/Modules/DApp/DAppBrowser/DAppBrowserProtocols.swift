protocol DAppBrowserViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: DAppBrowserModel)
}

protocol DAppBrowserPresenterProtocol: AnyObject {
    func setup()
    func process(message: Any)
}

protocol DAppBrowserInteractorInputProtocol: AnyObject {
    func setup()
    func process(message: Any)
}

protocol DAppBrowserInteractorOutputProtocol: AnyObject {
    func didReceive(error: Error)
    func didReceiveDApp(model: DAppBrowserModel)
}

protocol DAppBrowserWireframeProtocol: AlertPresentable, ErrorPresentable {}
