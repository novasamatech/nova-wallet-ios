import Foundation
import SoraFoundation
import RobinHood

final class DAppBrowserPresenter {
    weak var view: DAppBrowserViewProtocol?
    let wireframe: DAppBrowserWireframeProtocol
    let interactor: DAppBrowserInteractorInputProtocol
    let logger: LoggerProtocol?
    let localizationManager: LocalizationManager

    private(set) var favorites: [String: DAppFavorite]?

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

    private func provideFavoriteState() {
        guard let favorites = favorites, let page = browserPage else {
            return
        }

        let isFavorite = favorites[page.identifier] != nil

        view?.didReceiveFavorite(flag: isFavorite)
    }
}

extension DAppBrowserPresenter: DAppBrowserPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func process(page: DAppBrowserPage) {
        let oldHost = browserPage?.url.host
        browserPage = page

        provideFavoriteState()

        guard let newHost = browserPage?.url.host, newHost != oldHost else {
            return
        }

        interactor.process(host: newHost)
    }

    func process(message: Any, host: String, transport name: String) {
        interactor.process(message: message, host: host, transport: name)
    }

    func activateSearch(with query: String?) {
        wireframe.presentSearch(from: view, initialQuery: query, delegate: self)
    }

    func toggleFavorite() {
        guard let page = browserPage, let favorites = favorites else {
            return
        }

        if let favoriteDApp = favorites[page.identifier] {
            let name = favoriteDApp.label ?? page.title

            wireframe.showFavoritesRemovalConfirmation(
                from: view,
                name: name,
                locale: localizationManager.selectedLocale
            ) { [weak self] in
                self?.interactor.removeFromFavorites(record: favoriteDApp)
            }

        } else {
            wireframe.presentAddToFavoriteForm(from: view, page: page)
        }
    }

    func close() {
        let languages = localizationManager.selectedLocale.rLanguages

        let closeViewModel = AlertPresentableAction(
            title: R.string.localizable.commonClose(preferredLanguages: languages),
            style: .destructive
        ) { [weak self] in
            self?.wireframe.close(view: self?.view)
        }

        let viewModel = AlertPresentableViewModel(
            title: nil,
            message: R.string.localizable.dappBrowserCloseConfirmation(preferredLanguages: languages),
            actions: [closeViewModel],
            closeAction: R.string.localizable.commonCancel(preferredLanguages: languages)
        )

        wireframe.present(viewModel: viewModel, style: .actionSheet, from: view)
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

        provideFavoriteState()
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
