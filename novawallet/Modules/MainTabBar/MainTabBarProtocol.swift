import UIKit
import Foundation_iOS

protocol MainTabBarProtocol {
    var view: UIView! { get set }

    func presentedController() -> UIViewController?
    func topViewController() -> UIViewController?
}

protocol MainTabBarViewProtocol: ControllerBackedProtocol, MainTabBarProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int)
    func setSyncStatus(_ syncStatus: SharedSyncStatus)
}

protocol MainTabBarPresenterProtocol: AnyObject {
    func setup()
    func viewDidAppear()
    func activateStatusAction()
    func presentStatusAlert(_ closure: FlowStatusPresentingClosure)
}

protocol MainTabBarInteractorInputProtocol: AnyObject {
    func setup()
    func setPushNotificationsSetupScreenSeen()
    func requestNextOnLaunchAction()
}

protocol MainTabBarInteractorOutputProtocol: AnyObject {
    func didRequestImportAccount(source: SecretSource)
    func didRequestWalletMigration(with message: WalletMigrationMessage.Start)
    func didRequestScreenOpen(_ screen: UrlHandlingScreen)
    func didRequestPushScreenOpen(_ screen: PushNotification.OpenScreen)
    func didRequestReviewCloud(changes: CloudBackupSyncResult.Changes)
    func didFoundCloudBackup(issue: CloudBackupSyncResult.Issue)
    func didRequestPushNotificationsSetupOpen()
    func didSyncCloudBackup(on purpose: CloudBackupSynсPurpose)
    func didReceiveCloudSync(status: CloudBackupSyncMonitorStatus?)
}

protocol MainTabBarWireframeProtocol: AlertPresentable,
    AuthorizationAccessible,
    ModalAlertPresenting,
    BrowserOpening {
    func presentAccountImport(on view: MainTabBarViewProtocol?, source: SecretSource)

    func presentWalletMigration(on view: MainTabBarViewProtocol?, message: WalletMigrationMessage.Start)

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

protocol RootFlowStatusAlertPresenter: AnyObject {
    func presentStatusAlert(_ closure: FlowStatusPresentingClosure)
}
