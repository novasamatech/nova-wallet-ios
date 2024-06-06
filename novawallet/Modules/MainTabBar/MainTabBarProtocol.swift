import UIKit

protocol MainTabBarViewProtocol: ControllerBackedProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int)
}

protocol MainTabBarPresenterProtocol: AnyObject {
    func setup()
    func viewDidAppear()
}

protocol MainTabBarInteractorInputProtocol: AnyObject {
    func setup()
    func setPushNotificationsSetupScreenSeen()
}

protocol MainTabBarInteractorOutputProtocol: AnyObject {
    func didRequestImportAccount(source: SecretSource)
    func didRequestScreenOpen(_ screen: UrlHandlingScreen)
    func didRequestPushScreenOpen(_ screen: PushNotification.OpenScreen)
    func didRequestReviewCloud(changes: CloudBackupSyncResult.Changes)
    func didFoundCloudBackup(issue: CloudBackupSyncResult.Issue)
    func didRequestPushNotificationsSetupOpen()
}

protocol MainTabBarWireframeProtocol: AlertPresentable, AuthorizationAccessible {
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
        completion: @escaping () -> Void
    )

    func presentCloudBackupUnsyncedChanges(
        from view: MainTabBarViewProtocol?,
        onReviewUpdates: @escaping () -> Void
    )

    func presentCloudBackupUpdateFailedIfNeeded(
        from view: MainTabBarViewProtocol?,
        onReviewIssues: @escaping () -> Void
    )

    func presentReviewUpdates(from view: MainTabBarViewProtocol?)
}

protocol MainTabBarViewFactoryProtocol: AnyObject {
    static func createView() -> MainTabBarViewProtocol?
}
