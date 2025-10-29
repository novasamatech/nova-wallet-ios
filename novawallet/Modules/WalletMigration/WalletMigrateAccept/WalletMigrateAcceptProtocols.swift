import Foundation
import UIKit_iOS

protocol WalletMigrateAcceptViewProtocol: ControllerBackedProtocol {}

protocol WalletMigrateAcceptPresenterProtocol: AnyObject {
    func setup()
    func accept()
    func skip()
}

protocol WalletMigrateAcceptInteractorInputProtocol: AnyObject {
    func setup()
    func accept()
}

protocol WalletMigrateAcceptInteractorOutputProtocol: AnyObject {
    func didRequestMigration(from appScheme: String)
    func didCompleteMigration()
    func didFailMigration(with error: Error)
    func didReceiveCloudBackup(state: CloudBackupSyncState)
}

protocol WalletMigrateAcceptWireframeProtocol:
    AlertPresentable,
    ModalAlertPresenting,
    ErrorPresentable,
    CloudBackupRemindPresentable {
    func completeMigration(
        on view: WalletMigrateAcceptViewProtocol?,
        locale: Locale
    )
    func skipMigration(on view: WalletMigrateAcceptViewProtocol?)
}

extension WalletMigrateAcceptWireframeProtocol {
    func skipMigration(on view: WalletMigrateAcceptViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func createSuccessfulMigrationAlertClosure(locale: Locale) -> FlowStatusPresentingClosure {
        {
            $0.presentSuccessNotification(
                R.string(preferredLanguages: locale.rLanguages).localizable.walletMigrationSuccessfulAlertTitle(),
                from: $1
            )
        }
    }
}
