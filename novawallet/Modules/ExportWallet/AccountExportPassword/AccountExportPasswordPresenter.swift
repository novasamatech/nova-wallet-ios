import Foundation
import SoraFoundation

final class AccountExportPasswordPresenter {
    weak var view: AccountExportPasswordViewProtocol?
    let wireframe: AccountExportPasswordWireframeProtocol
    let interactor: AccountExportPasswordInteractorInputProtocol

    private let passwordInputViewModel = {
        InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))
    }()

    private let confirmationViewModel = {
        InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))
    }()

    let localizationManager: LocalizationManagerProtocol

    init(
        interactor: AccountExportPasswordInteractorInputProtocol,
        wireframe: AccountExportPasswordWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }
}

extension AccountExportPasswordPresenter: AccountExportPasswordPresenterProtocol {
    func setup() {
        view?.setPasswordInputViewModel(passwordInputViewModel)
        view?.setPasswordConfirmationViewModel(confirmationViewModel)
    }

    func proceed() {
        let password = passwordInputViewModel.inputHandler.normalizedValue

        guard password == confirmationViewModel.inputHandler.normalizedValue else {
            _ = wireframe.present(
                error: AccountExportPasswordError.passwordMismatch,
                from: view,
                locale: localizationManager.selectedLocale
            )
            return
        }

        interactor.exportAccount(password: password)
    }
}

extension AccountExportPasswordPresenter: AccountExportPasswordInteractorOutputProtocol {
    func didExport(json: RestoreJson) {
        wireframe.showJSONExport(json, from: view)
    }

    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}
