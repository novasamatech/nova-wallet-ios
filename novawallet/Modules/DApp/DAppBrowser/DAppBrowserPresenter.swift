import Foundation
import SoraFoundation
import Operation_iOS

final class DAppBrowserPresenter {
    weak var view: DAppBrowserViewProtocol?
    let wireframe: DAppBrowserWireframeProtocol
    let interactor: DAppBrowserInteractorInputProtocol
    let logger: LoggerProtocol?
    let localizationManager: LocalizationManager

    private(set) var favorites: [String: DAppFavorite]?
    private(set) var tabs: [DAppBrowserTab] = []
    private(set) var browserPage: DAppBrowserPage?

    init(
        interactor: DAppBrowserInteractorInputProtocol,
        wireframe: DAppBrowserWireframeProtocol,
        localizationManager: LocalizationManager,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func showState(error: DAppBrowserStateError) {
        let locale = localizationManager.selectedLocale
        let errorContent = error.toErrorContent(for: locale)

        let skipAction = R.string.localizable.commonSkip(preferredLanguages: locale.rLanguages)

        let reloadViewModel = AlertPresentableAction(
            title: R.string.localizable.commonReload(preferredLanguages: locale.rLanguages)
        ) { [weak self] in
            self?.interactor.reload()
        }

        let viewModel = AlertPresentableViewModel(
            title: errorContent.title,
            message: errorContent.message,
            actions: [reloadViewModel],
            closeAction: skipAction
        )

        wireframe.present(viewModel: viewModel, style: .alert, from: view)
    }

    private func updateSettingsState() {
        let canShowSettings = browserPage != nil

        view?.didSet(canShowSettings: canShowSettings)
    }

    func provideFavorite() {
        guard let browserPage else { return }

        let state = favorites?[browserPage.identifier] != nil

        view?.didSet(favorite: state)
    }

    func addToFavorites(page: DAppBrowserPage) {
        wireframe.presentAddToFavoriteForm(
            from: view,
            page: page
        )
    }

    func removeFromFavorites(dApp: DAppFavorite) {
        let name = dApp.label ?? browserPage?.title

        wireframe.showFavoritesRemovalConfirmation(
            from: view,
            name: name ?? "",
            locale: localizationManager.selectedLocale
        ) { [weak self] in
            self?.interactor.removeFromFavorites(record: dApp)
        }
    }
}

extension DAppBrowserPresenter: DAppBrowserPresenterProtocol {
    func actionFavorite(page: DAppBrowserPage) {
        if let favorite = favorites?[page.identifier] {
            removeFromFavorites(dApp: favorite)
        } else {
            addToFavorites(page: page)
        }
    }

    func setup() {
        interactor.setup()
    }

    func process(page: DAppBrowserPage) {
        let oldHost = browserPage?.url.host
        browserPage = page

        guard let newHost = browserPage?.url.host, newHost != oldHost else {
            return
        }

        interactor.process(host: newHost)
        updateSettingsState()
        provideFavorite()
    }

    func process(
        message: Any,
        host: String,
        transport name: String
    ) {
        interactor.process(
            message: message,
            host: host,
            transport: name
        )
    }

    func process(stateRenderer: DAppBrowserTabRendererProtocol) {
        interactor.process(stateRenderer: stateRenderer)
    }

    func activateSearch(with query: String?) {
        wireframe.presentSearch(
            from: view,
            initialQuery: query,
            delegate: self
        )
    }

    func showSettings(using isDesktop: Bool) {
        guard let page = browserPage else {
            return
        }

        let input = DAppSettingsInput(
            page: page,
            desktopMode: isDesktop
        )

        wireframe.presentSettings(
            from: view,
            state: input,
            delegate: self
        )
    }

    func close() {
        let languages = localizationManager.selectedLocale.rLanguages

        let closeViewModel = AlertPresentableAction(
            title: R.string.localizable.commonClose(preferredLanguages: languages),
            style: .destructive
        ) { [weak self] in
            self?.view?.didDecideClose()
            self?.wireframe.close(view: self?.view)
        }

        let viewModel = AlertPresentableViewModel(
            title: nil,
            message: R.string.localizable.commonCloseWhenChangesConfirmation(preferredLanguages: languages),
            actions: [closeViewModel],
            closeAction: R.string.localizable.commonCancel(preferredLanguages: languages)
        )

        wireframe.present(viewModel: viewModel, style: .actionSheet, from: view)
    }

    func showTabs(stateRenderer: DAppBrowserTabRendererProtocol) {
        interactor.saveLastTabState(renderer: stateRenderer)
    }

    func didLoadPage() {
        interactor.saveTabIfNeeded()
    }
}

extension DAppBrowserPresenter: DAppBrowserInteractorOutputProtocol {
    func didReceive(error: Error) {
        if let stateError = error as? DAppBrowserStateError {
            showState(error: stateError)
        } else if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            logger?.error("Did receive error: \(error)")
        }
    }

    func didReceiveDApp(model: DAppBrowserModel) {
        view?.didReceive(viewModel: model)
    }

    func didReceiveReplacement(
        transports: [DAppTransportModel],
        postExecution script: DAppScriptResponse
    ) {
        view?.didReceiveReplacement(transports: transports, postExecution: script)
    }

    func didReceive(response: DAppScriptResponse, forTransport name: String) {
        view?.didReceive(response: response, forTransport: name)
    }

    func didReceiveConfirmation(request: DAppOperationRequest, type: DAppSigningType) {
        wireframe.presentOperationConfirm(from: view, request: request, type: type, delegate: self)
    }

    func didReceiveAuth(request: DAppAuthRequest) {
        wireframe.presentAuth(from: view, request: request, delegate: self)
    }

    func didDetectPhishing(host: String) {
        logger?.warning("Did detect phishing host: \(host)")

        wireframe.presentPhishingDetected(from: view, delegate: self)
    }

    func didReceiveFavorite(changes: [DataProviderChange<DAppFavorite>]) {
        favorites = changes.mergeToDict(favorites ?? [:])
        provideFavorite()
    }

    func didChangeGlobal(settings: DAppGlobalSettings) {
        view?.didSet(isDesktop: settings.desktopMode)
    }

    func didReceiveTabs(_ models: [DAppBrowserTab]) {
        tabs = models

        view?.didReceiveTabsCount(viewModel: "\(models.count)")
    }

    func didSaveLastTabState() {
        wireframe.showTabs(from: view)
    }
}

extension DAppBrowserPresenter: DAppOperationConfirmDelegate {
    func didReceiveConfirmationResponse(
        _ response: DAppOperationResponse,
        for request: DAppOperationRequest
    ) {
        interactor.processConfirmation(response: response, forTransport: request.transportName)
    }
}

extension DAppBrowserPresenter: DAppSearchDelegate {
    func didCompleteDAppSearchResult(_ result: DAppSearchResult) {
        interactor.process(newQuery: result)
    }
}

extension DAppBrowserPresenter: DAppAuthDelegate {
    func didReceiveAuthResponse(_ response: DAppAuthResponse, for request: DAppAuthRequest) {
        interactor.processAuth(response: response, forTransport: request.transportName)
    }
}

extension DAppBrowserPresenter: DAppPhishingViewDelegate {
    func dappPhishingViewDidHide() {
        wireframe.close(view: view)
    }
}

extension DAppBrowserPresenter: DAppSettingsDelegate {
    func desktopModeDidChanged(page: DAppBrowserPage, isOn: Bool) {
        let settings = DAppGlobalSettings(identifier: page.domain, desktopMode: isOn)
        interactor.save(settings: settings)
    }
}
