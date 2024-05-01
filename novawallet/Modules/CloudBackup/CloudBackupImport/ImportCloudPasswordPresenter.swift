import Foundation
import SoraFoundation

final class ImportCloudPasswordPresenter {
    weak var view: ImportCloudPasswordViewProtocol?
    let wireframe: ImportCloudPasswordWireframeProtocol
    let interactor: ImportCloudPasswordInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol

    private let viewModel = InputViewModel(
        inputHandler: InputHandler(predicate: NSPredicate.notEmpty)
    )

    init(
        interactor: ImportCloudPasswordInteractorInputProtocol,
        wireframe: ImportCloudPasswordWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

extension ImportCloudPasswordPresenter: ImportCloudPasswordPresenterProtocol {
    func setup() {
        view?.didReceive(passwordViewModel: viewModel)
    }

    func activateForgotPassword() {
        wireframe.showCloudBackupDelete(
            from: view,
            reason: .forgotPassword,
            locale: localizationManager.selectedLocale
        ) { [weak self] in
            self?.interactor.deleteBackup()
        }
    }

    func activateContinue() {
        wireframe.showCloudBackupDelete(
            from: view,
            reason: .brokenOrEmpty,
            locale: localizationManager.selectedLocale
        ) { [weak self] in
            self?.logger.info("Backup removed due to damage")
        }
    }
}

extension ImportCloudPasswordPresenter: ImportCloudPasswordInteractorOutputProtocol {
    func didImportBackup() {}

    func didDeleteBackup() {}

    func didReceive(error: ImportCloudPasswordError) {
        logger.error("Error: \(error)")
    }
}
