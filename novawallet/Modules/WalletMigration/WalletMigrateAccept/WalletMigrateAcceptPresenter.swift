import Foundation
import Foundation_iOS

final class WalletMigrateAcceptPresenter {
    weak var view: WalletMigrateAcceptViewProtocol?
    let wireframe: WalletMigrateAcceptWireframeProtocol
    let interactor: WalletMigrateAcceptInteractorInputProtocol

    let localizationManager: LocalizationManagerProtocol

    let logger: LoggerProtocol

    private var cloudBackupState: CloudBackupSyncState?

    init(
        interactor: WalletMigrateAcceptInteractorInputProtocol,
        wireframe: WalletMigrateAcceptWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
        self.logger = logger
    }
}

extension WalletMigrateAcceptPresenter: WalletMigrateAcceptPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func accept() {
        if let cloudBackupState, cloudBackupState.canAutoSync {
            wireframe.showCloudBackupRemind(from: view) { [weak self] in
                self?.interactor.accept()
            }
        } else {
            interactor.accept()
        }
    }

    func skip() {
        wireframe.skipMigration(on: view)
    }
}

extension WalletMigrateAcceptPresenter: WalletMigrateAcceptInteractorOutputProtocol {
    func didRequestMigration(from scheme: String) {
        // TODO: Implement UI update
        logger.debug("Did start migration from \(scheme)")
    }

    func didCompleteMigration() {
        wireframe.completeMigration(
            on: view,
            locale: localizationManager.selectedLocale
        )
    }

    func didFailMigration(with error: Error) {
        logger.error("Did receive error \(error)")

        wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale)
    }

    func didReceiveCloudBackup(state: CloudBackupSyncState) {
        cloudBackupState = state
    }
}
