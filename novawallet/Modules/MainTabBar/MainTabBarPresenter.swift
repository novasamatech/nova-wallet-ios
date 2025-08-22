import Foundation
import Foundation_iOS

final class MainTabBarPresenter {
    weak var view: MainTabBarViewProtocol?
    var interactor: MainTabBarInteractorInputProtocol!
    var wireframe: MainTabBarWireframeProtocol!
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func viewDidAppear() {}

    func activateStatusAction() {
        wireframe.presentCloudBackupSettings(from: view)
    }

    func presentStatusAlert(_ closure: FlowStatusPresentingClosure) {
        closure(wireframe, view)
    }

    func presentDelayedOperationCreated() {
        wireframe.presentDelayedOperationCreated(from: view)
    }

    func presentMultisigNotificationsPromo() {
        wireframe.presentMultisigNotificationsPromo(from: view)
    }
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {
    func didRequestImportAccount(source: SecretSource) {
        wireframe.presentAccountImport(on: view, source: source)
    }

    func didRequestWalletMigration(with message: WalletMigrationMessage.Start) {
        wireframe.presentWalletMigration(on: view, message: message)
    }

    func didRequestScreenOpen(_ screen: UrlHandlingScreen) {
        wireframe.presentScreenIfNeeded(
            on: view,
            screen: screen,
            locale: localizationManager.selectedLocale
        )
    }

    func didRequestPushScreenOpen(_ screen: PushNotification.OpenScreen) {
        wireframe.presentScreenIfNeeded(
            on: view,
            screen: screen,
            locale: localizationManager.selectedLocale
        )
    }

    func didRequestReviewCloud(changes _: CloudBackupSyncResult.Changes) {
        wireframe.presentCloudBackupUnsyncedChanges(from: view) { [weak self] in
            self?.wireframe.presentCloudBackupSettings(from: self?.view)
        }
    }

    func didFoundCloudBackup(issue _: CloudBackupSyncResult.Issue) {
        wireframe.presentCloudBackupUpdateFailedIfNeeded(from: view) { [weak self] in
            self?.wireframe.presentCloudBackupSettings(from: self?.view)
        }
    }

    func didSyncCloudBackup(on purpose: CloudBackupSynсPurpose) {
        switch purpose {
        case .addChainAccount:
            wireframe.presentMultilineSuccessNotification(
                R.string.localizable.commonAccountHasChanged(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ),
                from: view?.controller.topModalViewController,
                completion: nil
            )
        case .createWallet:
            wireframe.presentMultilineSuccessNotification(
                R.string.localizable.commonWalletCreated(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ),
                from: view?.controller.topModalViewController,
                completion: nil
            )
        case .importWallet:
            wireframe.presentMultilineSuccessNotification(
                R.string.localizable.commonWalletImported(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ),
                from: view?.controller.topModalViewController,
                completion: nil
            )
        case .removeWallet:
            wireframe.presentMultilineSuccessNotification(
                R.string.localizable.commonWalletRemoved(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ),
                from: view?.controller.topModalViewController,
                completion: nil
            )
        case .unknown:
            break
        }
    }

    func didRequestPushNotificationsSetupOpen() {
        wireframe.presentPushNotificationsSetup(
            on: view,
            presentationCompletion: { [weak self] in
                self?.interactor.setPushNotificationsSetupScreenSeen()
            },
            flowCompletion: { [weak self] _ in
                self?.interactor.requestNextOnLaunchAction()
            }
        )
    }

    func didReceiveCloudSync(status: CloudBackupSyncMonitorStatus?) {
        switch status {
        case .noFile, .synced:
            view?.setSyncStatus(.synced)
        case .notDownloaded, .downloading, .uploading:
            view?.setSyncStatus(.syncing)
        case nil:
            view?.setSyncStatus(.disabled)
        }
    }
}
