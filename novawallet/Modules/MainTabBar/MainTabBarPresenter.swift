import Foundation
import SoraFoundation

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
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {
    func didRequestImportAccount(source: SecretSource) {
        wireframe.presentAccountImport(on: view, source: source)
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
            screen: screen
        )
    }

    func didRequestReviewCloud(changes: CloudBackupSyncResult.Changes) {
        wireframe.presentCloudBackupReview(
            from: view,
            changes: changes,
            delegate: self
        )
    }

    func didFailApplyingCloud(changes _: CloudBackupSyncResult.Changes, error _: Error) {
        // TODO: Show bottom sheet about error
    }

    func didRequestPushNotificationsSetupOpen() {
        wireframe.presentPushNotificationsSetup(on: view) { [weak self] in
            self?.interactor.setPushNotificationsSetupScreenSeen()
        }
    }
}

extension MainTabBarPresenter: CloudBackupReviewChangesDelegate {
    func cloudBackupReviewerDidApprove(changes _: CloudBackupSyncResult.Changes) {
        interactor.approveCloudBackupChanges()
    }
}
