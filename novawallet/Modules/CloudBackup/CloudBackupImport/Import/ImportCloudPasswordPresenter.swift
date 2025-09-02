import Foundation
import Foundation_iOS

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

    private func showBrokenOrEmptyDeleteConfirmation() {
        wireframe.showCloudBackupDelete(
            from: view,
            reason: .brokenOrEmpty,
            locale: localizationManager.selectedLocale
        ) { [weak self] in
            self?.view?.didStartLoading()
            self?.interactor.deleteBackup()
        }
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
            self?.view?.didStartLoading()
            self?.interactor.deleteBackup()
        }
    }

    func activateContinue() {
        guard viewModel.inputHandler.completed else {
            return
        }

        let password = viewModel.inputHandler.normalizedValue

        view?.didStartLoading()
        interactor.importBackup(for: password)
    }
}

extension ImportCloudPasswordPresenter: ImportCloudPasswordInteractorOutputProtocol {
    func didImportBackup(with password: String) {
        view?.didStopLoading()

        wireframe.proceedAfterImport(
            from: view,
            password: password,
            locale: localizationManager.selectedLocale
        )
    }

    func didDeleteBackup() {
        view?.didStopLoading()

        wireframe.proceedAfterDelete(from: view, locale: localizationManager.selectedLocale)
    }

    func didReceive(error: ImportCloudPasswordError) {
        logger.error("Error: \(error)")

        guard let view else {
            return
        }

        view.didStopLoading()

        switch error {
        case .backupBroken, .emptyBackup:
            showBrokenOrEmptyDeleteConfirmation()
        case .invalidPassword:
            wireframe.presentInvalidBackupPassword(from: view, locale: localizationManager.selectedLocale)
        case .deleteFailed, .importInternal:
            wireframe.presentNoCloudConnection(from: view, locale: localizationManager.selectedLocale)
        case .selectedWallet:
            _ = wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale)
        }
    }
}
