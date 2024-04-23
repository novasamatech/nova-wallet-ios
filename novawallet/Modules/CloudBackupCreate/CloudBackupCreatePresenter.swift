import Foundation
import SoraFoundation

final class CloudBackupCreatePresenter {
    weak var view: CloudBackupCreateViewProtocol?
    let wireframe: CloudBackupCreateWireframeProtocol
    let interactor: CloudBackupCreateInteractorInputProtocol
    let logger: LoggerProtocol

    let passwordValidator: CloudBackupPasswordValidating
    let hintsViewModelFactory: CloudBackPasswordViewModelFactoryProtocol

    private let passwordViewModel = InputViewModel(
        inputHandler: InputHandler(predicate: NSPredicate.notEmpty)
    )

    private let confirmViewModel = InputViewModel(
        inputHandler: InputHandler(predicate: NSPredicate.notEmpty)
    )

    var password: String? {
        passwordViewModel.inputHandler.normalizedValue
    }

    var confirmation: String? {
        confirmViewModel.inputHandler.normalizedValue
    }

    init(
        interactor: CloudBackupCreateInteractorInputProtocol,
        wireframe: CloudBackupCreateWireframeProtocol,
        hintsViewModelFactory: CloudBackPasswordViewModelFactoryProtocol,
        passwordValidator: CloudBackupPasswordValidating,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.hintsViewModelFactory = hintsViewModelFactory
        self.passwordValidator = passwordValidator
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideInputViewModels() {
        view?.didReceive(passwordViewModel: passwordViewModel)
        view?.didReceive(confirmViewModel: confirmViewModel)
    }

    private func provideHintsViewModel() {
        let result = passwordValidator.validate(password: password, confirmation: confirmation)

        let hints = hintsViewModelFactory.createHints(from: result, locale: selectedLocale)

        view?.didRecieve(hints: hints)
        view?.didReceive(canContinue: result == .all)
    }

    private func initiateWalletCreation() {
        if let password, passwordValidator.isValid(password: password, confirmation: confirmation) {
            view?.didStartLoading()
            interactor.createWallet(for: password)
        }
    }
}

extension CloudBackupCreatePresenter: CloudBackupCreatePresenterProtocol {
    func setup() {
        provideInputViewModels()
        provideHintsViewModel()
    }

    func applyEnterPasswordChange() {
        provideHintsViewModel()
    }

    func applyConfirmPasswordChange() {
        provideHintsViewModel()
    }

    func activateContinue() {
        initiateWalletCreation()
    }
}

extension CloudBackupCreatePresenter: CloudBackupCreateInteractorOutputProtocol {
    func didCreateWallet() {
        view?.didStopLoading()

        wireframe.proceed(from: view)
    }

    func didReceive(error: CloudBackupCreateInteractorError) {
        logger.error("Did receive error: \(error)")

        view?.didStopLoading()

        switch error {
        case .mnemonicCreation, .walletCreation, .walletSave:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.initiateWalletCreation()
            }
        case .backup:
            if let view = view {
                wireframe.presentNoCloudConnection(from: view, locale: selectedLocale)
            }
        case .alreadyInProgress:
            break
        }
    }
}

extension CloudBackupCreatePresenter: Localizable {
    func applyLocalization() {
        provideHintsViewModel()
    }
}
