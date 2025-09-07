import Foundation
import Foundation_iOS

final class CloudBackupAddWalletPresenter: BaseUsernameSetupPresenter {
    let wireframe: CloudBackupAddWalletWireframeProtocol
    let interactor: CloudBackupAddWalletInteractorInputProtocol
    let logger: LoggerProtocol

    init(
        interactor: CloudBackupAddWalletInteractorInputProtocol,
        wireframe: CloudBackupAddWalletWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger

        super.init()

        self.localizationManager = localizationManager
    }

    private func provideBadge() {
        let title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonCloudBackup().uppercased()

        let icon = R.image.iconPositiveCheckmarkFilled()

        let viewModel = TitleIconViewModel(title: title, icon: icon)

        view?.setBadge(viewModel: viewModel)
    }

    override func setup() {
        super.setup()

        provideBadge()
    }
}

extension CloudBackupAddWalletPresenter: UsernameSetupPresenterProtocol {
    func proceed() {
        let walletName = viewModel.inputHandler.value
        interactor.createWallet(for: walletName)
    }
}

extension CloudBackupAddWalletPresenter: CloudBackupAddWalletInteractorOutputProtocol {
    func didCreateWallet() {
        wireframe.proceed(from: view)
    }

    func didReceive(error: CloudBackupAddWalletInteractorError) {
        logger.error("Error: \(error)")

        if !wireframe.present(error: error, from: view, locale: selectedLocale) {
            _ = wireframe.present(error: CommonError.dataCorruption, from: view, locale: selectedLocale)
        }
    }
}

extension CloudBackupAddWalletPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideBadge()
        }
    }
}
