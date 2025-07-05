import Foundation
import Foundation_iOS

final class MultisigTxDetailsPresenter {
    weak var view: MultisigTxDetailsViewProtocol?
    let wireframe: MultisigTxDetailsWireframeProtocol
    let interactor: MultisigTxDetailsInteractorInputProtocol

    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol?

    init(
        interactor: MultisigTxDetailsInteractorInputProtocol,
        wireframe: MultisigTxDetailsWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
        self.logger = logger
    }
}

extension MultisigTxDetailsPresenter: MultisigTxDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension MultisigTxDetailsPresenter: MultisigTxDetailsInteractorOutputProtocol {
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
