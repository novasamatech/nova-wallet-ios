import Foundation
import SoraFoundation

final class DAppTxDetailsPresenter {
    weak var view: DAppTxDetailsViewProtocol?
    let wireframe: DAppTxDetailsWireframeProtocol
    let interactor: DAppTxDetailsInteractorInputProtocol

    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol?

    init(
        interactor: DAppTxDetailsInteractorInputProtocol,
        wireframe: DAppTxDetailsWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
        self.logger = logger
    }
}

extension DAppTxDetailsPresenter: DAppTxDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension DAppTxDetailsPresenter: DAppTxDetailsInteractorOutputProtocol {
    func didReceive(displayResult: Result<String, Error>) {
        switch displayResult {
        case let .success(txDetails):
            view?.didReceive(txDetails: txDetails)
        case let .failure(error):
            if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
                logger?.error("Display result error: \(error)")
            }
        }
    }
}
