protocol DAppBrowserViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: DAppBrowserModel)
    func didReceive(response: PolkadotExtensionResponse)
}

protocol DAppBrowserPresenterProtocol: AnyObject {
    func setup()
    func process(message: Any)
    func activateSearch(with query: String?)
    func toggleFavorite()
}

protocol DAppBrowserInteractorInputProtocol: AnyObject {
    func setup()
    func process(message: Any)
    func processConfirmation(response: DAppOperationResponse)
    func process(newQuery: String)
    func processAuth(response: DAppAuthResponse)
}

protocol DAppBrowserInteractorOutputProtocol: AnyObject {
    func didReceive(error: Error)
    func didReceiveDApp(model: DAppBrowserModel)
    func didReceive(response: PolkadotExtensionResponse)
    func didReceiveConfirmation(request: DAppOperationRequest)
    func didReceiveAuth(request: DAppAuthRequest)
}

protocol DAppBrowserWireframeProtocol: AlertPresentable, ErrorPresentable {
    func presentOperationConfirm(
        from view: DAppBrowserViewProtocol?,
        request: DAppOperationRequest,
        delegate: DAppOperationConfirmDelegate
    )

    func presentSearch(
        from view: DAppBrowserViewProtocol?,
        initialQuery: String?,
        delegate: DAppSearchDelegate
    )

    func presentAuth(
        from view: DAppBrowserViewProtocol?,
        request: DAppAuthRequest,
        delegate: DAppAuthDelegate
    )
}
