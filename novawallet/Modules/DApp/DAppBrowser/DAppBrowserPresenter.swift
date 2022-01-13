import Foundation
import SoraFoundation

final class DAppBrowserPresenter {
    weak var view: DAppBrowserViewProtocol?
    let wireframe: DAppBrowserWireframeProtocol
    let interactor: DAppBrowserInteractorInputProtocol
    let logger: LoggerProtocol?
    let localizationManager: LocalizationManager

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
}

extension DAppBrowserPresenter: DAppBrowserPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func process(message: Any) {
        interactor.process(message: message)
    }

    func activateSearch(with query: String?) {
        wireframe.presentSearch(from: view, initialQuery: query, delegate: self)
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

    func didReceive(response: PolkadotExtensionResponse) {
        view?.didReceive(response: response)
    }

    func didReceiveConfirmation(request: DAppOperationRequest, type: DAppSigningType) {
        wireframe.presentOperationConfirm(from: view, request: request, type: type, delegate: self)
    }

    func didReceiveAuth(request: DAppAuthRequest) {
        wireframe.presentAuth(from: view, request: request, delegate: self)
    }
}

extension DAppBrowserPresenter: DAppOperationConfirmDelegate {
    func didReceiveConfirmationResponse(_ response: DAppOperationResponse, for _: DAppOperationRequest) {
        interactor.processConfirmation(response: response)
    }
}

extension DAppBrowserPresenter: DAppSearchDelegate {
    func didCompleteDAppSearchQuery(_ query: String) {
        interactor.process(newQuery: query)
    }
}

extension DAppBrowserPresenter: DAppAuthDelegate {
    func didReceiveAuthResponse(_ response: DAppAuthResponse, for _: DAppAuthRequest) {
        interactor.processAuth(response: response)
    }
}
