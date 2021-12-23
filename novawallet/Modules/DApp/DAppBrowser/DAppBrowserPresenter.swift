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

    func toggleFavorite() {}
}

extension DAppBrowserPresenter: DAppBrowserInteractorOutputProtocol {
    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            logger?.error("Did receive error: \(error)")
        }
    }

    func didReceiveDApp(model: DAppBrowserModel) {
        view?.didReceive(viewModel: model)
    }

    func didReceive(response: PolkadotExtensionResponse) {
        view?.didReceive(response: response)
    }

    func didReceiveConfirmation(request: DAppOperationRequest) {
        wireframe.presentOperationConfirm(from: view, request: request, delegate: self)
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
