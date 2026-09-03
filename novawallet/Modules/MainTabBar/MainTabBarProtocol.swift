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
    func presentDelayedOperationCreated()
}

protocol MainTabBarInteractorInputProtocol: AnyObject {
    func setup()
    func setPushNotificationsSetupScreenSeen()
    func setAnalyticsConsent(enabled: Bool)
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
    func didRequestLegalConsentOpen()
    func didRequestAnalyticsConsentOpen()
    func didRequestMultisigNotificationsPromoOpen(with params: MultisigNotificationsPromoParams)
    func didRequestAHMInfoOpen(with info: [AHMRemoteData])
    func didSyncCloudBackup(on purpose: CloudBackupSynсPurpose)
    func didReceiveCloudSync(status: CloudBackupSyncMonitorStatus?)
}

protocol MainTabBarWireframeProtocol: AlertPresentable,
    AuthorizationAccessible,
    ModalAlertPresenting,
    BrowserOpening,
    MessageSheetPresentable,
    FeatureSupportChecking {
    func presentAccountImport(on view: MainTabBarViewProtocol?, source: SecretSource)

    func presentWalletMigration(on view: MainTabBarViewProtocol?, message: WalletMigrationMessage.Start)

    func presentScreenIfNeeded(
        on view: MainTabBarViewProtocol?,
        screen: UrlHandlingScreen,
        locale: Locale
    )
    func presentScreenIfNeeded(
        on view: MainTabBarViewProtocol?,
        screen: PushNotification.OpenScreen,
        locale: Locale
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

    func presentDelayedOperationCreated(from view: MainTabBarViewProtocol?)

    func presentMultisigNotificationsPromo(
        from view: MainTabBarViewProtocol?,
        with params: MultisigNotificationsPromoParams
    )

    func presentAssetHubMigrationInfoScreen(
        in view: MainTabBarViewProtocol?,
        with info: [AHMRemoteData]
    )

    func presentLegalConsent(
        from view: MainTabBarViewProtocol?,
        completion: @escaping () -> Void
    )

    /// `onUnavailable` covers the sheet failing to construct. It must not be wired to the
    /// decline handler: `markPromptSeen()` is never cleared, so recording a decision the
    /// user was never shown locks them out of the prompt for the life of the install.
    func presentAnalyticsConsent(
        from view: MainTabBarViewProtocol?,
        onEnable: @escaping () -> Void,
        onDecline: @escaping () -> Void,
        onUnavailable: @escaping () -> Void
    )
}

protocol MainTabBarViewFactoryProtocol: AnyObject {
    static func createView() -> MainTabBarViewProtocol?
}

protocol RootFlowStatusAlertPresenter: AnyObject {
    func presentStatusAlert(_ closure: FlowStatusPresentingClosure)
}
