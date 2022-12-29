import Foundation
import RobinHood

protocol DAppBrowserViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: DAppBrowserModel)
    func didReceive(response: DAppScriptResponse, forTransport name: String)
    func didReceiveReplacement(
        transports: [DAppTransportModel],
        postExecution script: DAppScriptResponse
    )
    func didReceive(settings: DAppGlobalSettings)
}

protocol DAppBrowserPresenterProtocol: AnyObject {
    func setup()
    func process(page: DAppBrowserPage)
    func process(message: Any, host: String, transport name: String)
    func activateSearch(with query: String?)
    func showSettings()
    func close()
}

protocol DAppBrowserInteractorInputProtocol: AnyObject {
    func setup()
    func process(host: String)
    func process(message: Any, host: String, transport name: String)
    func processConfirmation(response: DAppOperationResponse, forTransport name: String)
    func process(newQuery: DAppSearchResult)
    func processAuth(response: DAppAuthResponse, forTransport name: String)
    func removeFromFavorites(record: DAppFavorite)
    func reload()
    func save(settings: DAppGlobalSettings)
}

protocol DAppBrowserInteractorOutputProtocol: AnyObject {
    func didReceive(error: Error)
    func didReceiveDApp(model: DAppBrowserModel)
    func didReceiveReplacement(
        transports: [DAppTransportModel],
        postExecution script: DAppScriptResponse
    )
    func didReceive(response: DAppScriptResponse, forTransport name: String)
    func didReceiveConfirmation(
        request: DAppOperationRequest,
        type: DAppSigningType
    )
    func didReceiveAuth(request: DAppAuthRequest)
    func didDetectPhishing(host: String)
    func didReceiveFavorite(changes: [DataProviderChange<DAppFavorite>])
    func didReceive(settings: [DAppGlobalSettings])
}

protocol DAppBrowserWireframeProtocol: DAppAlertPresentable, ErrorPresentable {
    func presentOperationConfirm(
        from view: DAppBrowserViewProtocol?,
        request: DAppOperationRequest,
        type: DAppSigningType,
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

    func presentPhishingDetected(
        from view: DAppBrowserViewProtocol?,
        delegate: DAppPhishingViewDelegate
    )

    func presentAddToFavoriteForm(
        from view: DAppBrowserViewProtocol?,
        page: DAppBrowserPage
    )

    func presentSettings(
        from view: DAppBrowserViewProtocol?,
        state: DAppSettingsInput,
        delegate: DAppSettingsDelegate
    )

    func hideSettings(from view: DAppBrowserViewProtocol?)

    func close(view: DAppBrowserViewProtocol?)
}
