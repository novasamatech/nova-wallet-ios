import Foundation
import Operation_iOS

protocol DAppBrowserTransitionProtocol {
    func idForTransitioningTab() -> UUID?
}

protocol DAppBrowserViewProtocol: ControllerBackedProtocol, DAppBrowserTransitionProtocol {
    func didReceive(viewModel: DAppBrowserModel)
    func didReceiveTabsCount(viewModel: DAppBrowserTabsButtonViewModel)
    func didReceive(response: DAppScriptResponse)
    func didReceiveReplacement(
        transports: [DAppTransportModel],
        postExecution script: DAppScriptResponse
    )
    func didSet(isDesktop: Bool)
    func didSet(canShowSettings: Bool)
    func didSet(favorite: Bool)
    func didDecideClose()
    func didReceiveRenderRequest()
}

protocol DAppBrowserPresenterProtocol: AnyObject {
    func setup()

    func didLoadPage()

    func process(page: DAppBrowserPage)

    func process(message: Any, transport name: String)

    func process(stateRender: DAppBrowserTabRenderProtocol)

    func actionFavorite()

    func activateSearch()
    func showSettings(using isDesktop: Bool)
    func close(stateRender: DAppBrowserTabRenderProtocol)
    func showTabs(stateRender: DAppBrowserTabRenderProtocol)
    func willDismissInteractive(stateRender: DAppBrowserTabRenderProtocol)
}

protocol DAppBrowserInteractorInputProtocol: AnyObject {
    func setup()

    func process(host: String)

    func process(
        message: Any,
        host: String,
        transport name: String
    )

    func process(stateRender: DAppBrowserTabRenderProtocol)

    func processConfirmation(response: DAppOperationResponse, forTransport name: String)
    func process(newQuery: DAppSearchResult)
    func processAuth(response: DAppAuthResponse, forTransport name: String)
    func removeFromFavorites(record: DAppFavorite)
    func reload()
    func save(settings: DAppGlobalSettings)
    func saveTabIfNeeded()
    func saveLastTabState(render: DAppBrowserTabRenderProtocol)
    func close()
}

protocol DAppBrowserInteractorOutputProtocol: AnyObject {
    func didReceive(error: Error)
    func didReceiveTabs(_ models: [DAppBrowserTab])
    func didReceiveDApp(model: DAppBrowserModel)
    func didReceiveReplacement(
        transports: [DAppTransportModel],
        postExecution script: DAppScriptResponse
    )
    func didReceive(response: DAppScriptResponse)
    func didReceiveConfirmation(
        request: DAppOperationRequest,
        type: DAppSigningType
    )
    func didReceiveAuth(request: DAppAuthRequest)
    func didDetectPhishing(host: String)
    func didReceiveFavorite(changes: [DataProviderChange<DAppFavorite>])
    func didChangeGlobal(settings: DAppGlobalSettings)
    func didReceiveRenderRequest()
    func didSaveLastTabState()
}

protocol DAppBrowserWireframeProtocol: DAppAlertPresentable,
    ErrorPresentable,
    DAppBrowserSearchPresentable {
    func presentOperationConfirm(
        from view: DAppBrowserViewProtocol?,
        request: DAppOperationRequest,
        type: DAppSigningType,
        delegate: DAppOperationConfirmDelegate
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

    func close(view: ControllerBackedProtocol?)

    func showTabs(from view: DAppBrowserViewProtocol?)
}
