import Foundation
import Foundation_iOS
import NovaAnalytics

final class CloudBackupConfirmPasswordPresenter: BaseCloudBackupCreatePresenter, AnalyticsTracking {
    let interactor: CloudBackupCreateInteractorInputProtocol

    private var passwordToConfirm: String?

    private let isWalletCreation: Bool

    init(
        interactor: CloudBackupCreateInteractorInputProtocol,
        wireframe: CloudBackupCreateWireframeProtocol,
        hintsViewModelFactory: CloudBackPasswordViewModelFactoryProtocol,
        passwordValidator: CloudBackupPasswordValidating,
        passwordToConfirm: String?,
        isWalletCreation: Bool,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.interactor = interactor
        self.passwordToConfirm = passwordToConfirm
        self.isWalletCreation = isWalletCreation

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

        if isWalletCreation {
            trackAnalytics(.walletCreationCompleted(method: .create, duration: nil))
        }

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
