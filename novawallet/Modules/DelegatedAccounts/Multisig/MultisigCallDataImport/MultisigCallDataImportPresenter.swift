import Foundation
import Foundation_iOS

final class MultisigCallDataImportPresenter {
    weak var view: MultisigCallDataImportViewProtocol?
    let wireframe: MultisigCallDataImportWireframeProtocol
    let interactor: MultisigCallDataImportInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol

    private let viewModel = InputViewModel(
        inputHandler: InputHandler(predicate: NSPredicate.notEmpty),
        placeholder: "0xAB"
    )

    init(
        interactor: MultisigCallDataImportInteractorInputProtocol,
        wireframe: MultisigCallDataImportWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension MultisigCallDataImportPresenter {
    func handleCallDataInput(_ callData: String) {
        viewModel.inputHandler.changeValue(to: callData)
        view?.didReceive(callDataViewModel: viewModel)
    }

    func showValidationError(_ error: Error) {
        guard let validationError = error as? MultisigCallDataImportError else {
            return
        }

        switch validationError {
        case .invalidCallData:
            wireframe.present(
                message: R.string(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ).localizable.callDataValidationErrorMessage(),
                title: R.string(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ).localizable.callDataValidationErrorTitle(),
                closeAction: R.string(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ).localizable.commonClose(),
                from: view
            )
        case let .differentHash(hash):
            wireframe.present(
                message: R.string(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ).localizable.callDataValidationHashMatchingErrorMessage(hash),
                title: R.string(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ).localizable.callDataValidationErrorTitle(),
                closeAction: R.string(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ).localizable.commonClose(),
                from: view
            )
        }
    }
}

// MARK: - MultisigCallDataImportPresenterProtocol

extension MultisigCallDataImportPresenter: MultisigCallDataImportPresenterProtocol {
    func setup() {
        view?.didReceive(callDataViewModel: viewModel)
    }

    func save() {
        let callData = viewModel.inputHandler.normalizedValue

        interactor.importCallData(callData)
    }
}

// MARK: - MultisigCallDataImportInteractorOutputProtocol

extension MultisigCallDataImportPresenter: MultisigCallDataImportInteractorOutputProtocol {
    func didReceive(importResult: Result<Void, Error>) {
        switch importResult {
        case .success:
            wireframe.proceedAfterImport(from: view)
        case let .failure(error):
            showValidationError(error)
        }
    }
}
