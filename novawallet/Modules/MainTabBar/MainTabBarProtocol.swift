import UIKit

protocol MainTabBarProtocol {
    var view: UIView! { get set }
}

protocol MainTabBarViewProtocol: ControllerBackedProtocol, MainTabBarProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int)
    func setSyncStatus(_ syncStatus: SharedSyncStatus)
}

protocol MainTabBarPresenterProtocol: AnyObject {
    func setup()
    func viewDidAppear()
    func activateStatusAction()
}

protocol MainTabBarInteractorInputProtocol: AnyObject {
    func setup()
    func setPushNotificationsSetupScreenSeen()
    func requestNextOnLaunchAction()
}

protocol MainTabBarInteractorOutputProtocol: AnyObject {
    func didRequestImportAccount(source: SecretSource)
    func didRequestScreenOpen(_ screen: UrlHandlingScreen)
    func didRequestPushScreenOpen(_ screen: PushNotification.OpenScreen)
    func didRequestReviewCloud(changes: CloudBackupSyncResult.Changes)
    func didFoundCloudBackup(issue: CloudBackupSyncResult.Issue)
    func didRequestPushNotificationsSetupOpen()
    func didSyncCloudBackup(on purpose: CloudBackupSynсPurpose)
    func didReceiveCloudSync(status: CloudBackupSyncMonitorStatus?)
}

protocol MainTabBarWireframeProtocol: AlertPresentable, AuthorizationAccessible, ModalAlertPresenting {
    func presentAccountImport(on view: MainTabBarViewProtocol?, source: SecretSource)
    func presentScreenIfNeeded(
        on view: MainTabBarViewProtocol?,
        screen: UrlHandlingScreen,
        locale: Locale
    )
    func presentScreenIfNeeded(
        on view: MainTabBarViewProtocol?,
        screen: PushNotification.OpenScreen
    )
    func presentPushNotificationsSetup(
        on view: MainTabBarViewProtocol?,
        presentationCompletion: @escaping () -> Void,
        flowCompletion: @escaping (Bool) -> Void
    )

    func presentCloudBackupUnsyncedChanges(
        from view: MainTabBarViewProtocol?,
        onReviewUpdates: @escaping () -> Void
    )

    func presentCloudBackupUpdateFailedIfNeeded(
        from view: MainTabBarViewProtocol?,
        onReviewIssues: @escaping () -> Void
    )

    func presentCloudBackupSettings(from view: MainTabBarViewProtocol?)
}

protocol MainTabBarViewFactoryProtocol: AnyObject {
    static func createView() -> MainTabBarViewProtocol?
}
