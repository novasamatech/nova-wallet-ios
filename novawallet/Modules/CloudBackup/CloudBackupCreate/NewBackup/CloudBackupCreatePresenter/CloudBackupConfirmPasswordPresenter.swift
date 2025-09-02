import Foundation
import Foundation_iOS

final class CloudBackupConfirmPasswordPresenter: BaseCloudBackupCreatePresenter {
    let interactor: CloudBackupCreateInteractorInputProtocol

    private var passwordToConfirm: String?

    init(
        interactor: CloudBackupCreateInteractorInputProtocol,
        wireframe: CloudBackupCreateWireframeProtocol,
        hintsViewModelFactory: CloudBackPasswordViewModelFactoryProtocol,
        passwordValidator: CloudBackupPasswordValidating,
        passwordToConfirm: String?,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.interactor = interactor
        self.passwordToConfirm = passwordToConfirm

        super.init(
            wireframe: wireframe,
            hintsViewModelFactory: hintsViewModelFactory,
            passwordValidator: passwordValidator,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    private func initiateWalletCreation() {
        let validation = createValidation()

        if let password, passwordValidator.isValid(with: validation) {
            view?.didStartLoading()
            interactor.createWallet(for: password)
        }
    }

    override func createValidation() -> CloudBackup.PasswordValidationType {
        .confirmation(password: passwordToConfirm, confirmation: password)
    }

    override func actionContinue() {
        initiateWalletCreation()
    }

    override func actionOnAppear() {}
}

extension CloudBackupConfirmPasswordPresenter: CloudBackupCreateInteractorOutputProtocol {
    func didCreateWallet() {
        view?.didStopLoading()

        wireframe.proceed(
            from: view,
            locale: selectedLocale
        )
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
