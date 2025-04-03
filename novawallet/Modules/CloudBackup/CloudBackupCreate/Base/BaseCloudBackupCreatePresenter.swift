import Foundation
import Foundation_iOS

class BaseCloudBackupCreatePresenter {
    weak var view: CloudBackupCreateViewProtocol?
    let wireframe: CloudBackupCreateWireframeProtocol
    let logger: LoggerProtocol

    let passwordValidator: CloudBackupPasswordValidating
    let hintsViewModelFactory: CloudBackPasswordViewModelFactoryProtocol

    private let passwordViewModel = InputViewModel(
        inputHandler: InputHandler(predicate: NSPredicate.notEmpty)
    )

    var password: String? {
        passwordViewModel.inputHandler.normalizedValue
    }

    init(
        wireframe: CloudBackupCreateWireframeProtocol,
        hintsViewModelFactory: CloudBackPasswordViewModelFactoryProtocol,
        passwordValidator: CloudBackupPasswordValidating,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.wireframe = wireframe
        self.hintsViewModelFactory = hintsViewModelFactory
        self.passwordValidator = passwordValidator
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideInputViewModels() {
        view?.didReceive(passwordViewModel: passwordViewModel)
    }

    private func provideHintsViewModel() {
        let validation = createValidation()

        let result = passwordValidator.validate(with: validation)

        let hints = hintsViewModelFactory.createHints(
            from: result,
            locale: selectedLocale
        )

        view?.didRecieve(hints: hints)
        view?.didReceive(canContinue: result == .all(for: validation))
    }

    func createValidation() -> CloudBackup.PasswordValidationType {
        fatalError("Must be overriden by subsclass")
    }

    func actionContinue() {
        fatalError("Must be overriden by subsclass")
    }

    func actionOnAppear() {
        fatalError("Must be overriden by subsclass")
    }
}

extension BaseCloudBackupCreatePresenter: CloudBackupCreatePresenterProtocol {
    func setup() {
        provideInputViewModels()
        provideHintsViewModel()
    }

    func applyEnterPasswordChange() {
        provideHintsViewModel()
    }

    func activateContinue() {
        actionContinue()
    }

    func activateOnAppear() {
        actionOnAppear()
    }
}

extension BaseCloudBackupCreatePresenter: Localizable {
    func applyLocalization() {
        provideHintsViewModel()
    }
}
