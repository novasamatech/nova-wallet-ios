import UIKit
import Keystore_iOS

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var settings: SettingsManagerProtocol { SettingsManager.shared }

    var urlHandlingFacade: URLHandlingServiceFacadeProtocol { URLHandlingServiceFacade.shared }

    var isUnitTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UNITTEST")
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: AppLaunchOptions?
    ) -> Bool {
        guard !isUnitTesting else { return true }

        let rootWindow = NovaWindow()
        window = rootWindow

        // the requirement is to set the delegate before living didFinishLaunching
        setupPushNotificationsDelegate()

        let presenter = RootPresenterFactory.createPresenter(with: rootWindow)
        presenter.loadOnLaunch()

        rootWindow.makeKeyAndVisible()

        // setup the facade after dependencies are proper initialized by Root module
        setupUrlHandling()

        markAppFirstTimeLaunchIfNeeded()

        return true
    }

    func setupPushNotificationsDelegate() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
    }

    func setupUrlHandling() {
        urlHandlingFacade.configure()
    }

    func markAppFirstTimeLaunchIfNeeded() {
        guard settings.isAppFirstLaunch else { return }

        settings.isAppFirstLaunch = false
    }

    func application(
        _: UIApplication,
        open url: URL,
        options _: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        urlHandlingFacade.handle(url: url)
    }

    func application(_: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?) -> UIInterfaceOrientationMask {
        DeviceOrientationManager.shared.enabledOrientations
    }

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Logger.shared.debug("Did receive APNS push token")

        PushNotificationsServiceFacade.shared.updateAPNS(token: deviceToken)
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.shared.error("Failed to register push notifications: \(error)")
    }

    func application(
        _: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler _: @escaping ([any UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard
            userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL
        else {
            return false
        }

        return urlHandlingFacade.handle(url: url)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .badge, .sound])
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        PushNotificationHandlingService.shared.handle(userInfo: userInfo) { _ in
            completionHandler()
        }
    }
}

typealias AppLaunchOptions = [UIApplication.LaunchOptionsKey: Any]
