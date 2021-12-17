protocol DAppBrowserViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: DAppBrowserModel)
    func didReceive(response: PolkadotExtensionResponse)
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
    func didReceive(response: PolkadotExtensionResponse)
}

protocol DAppBrowserWireframeProtocol: AlertPresentable, ErrorPresentable {}
