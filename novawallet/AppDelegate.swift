import UIKit
import BranchSDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var isUnitTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UNITTEST")
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        guard !isUnitTesting else { return true }

        let rootWindow = NovaWindow()
        window = rootWindow

        // the requirement is to set the delegate before living didFinishLaunching
        setupPushNotificationsDelegate()

        setupBranch(with: launchOptions)

        let presenter = RootPresenterFactory.createPresenter(with: rootWindow)
        presenter.loadOnLaunch()

        rootWindow.makeKeyAndVisible()
        return true
    }

    func application(
        _: UIApplication,
        open url: URL,
        options _: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        URLHandlingService.shared.handle(url: url)
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

        URLHandlingService.shared.handle(url: url)

        return true
    }
}

private extension AppDelegate {
    func setupPushNotificationsDelegate() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
    }

    func setupBranch(with launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        Branch.setUseTestBranchKey(true)
        Branch.enableLogging()

        Branch.getInstance().initSession(launchOptions: launchOptions) { params, _ in
            Logger.shared.debug("Did open branch: \(String(describing: params))")

            guard let hasLink = params?["+clicked_branch_link"] as? NSNumber, hasLink.boolValue else {
                Logger.shared.debug("No branch link")
                return
            }

            guard let action = params?["action"] as? String, let mnemonic = params?["mnemonic"] as? String else {
                Logger.shared.debug("No mnemonic")
                return
            }

            guard let url = URL(string: "https://f8qk2.test-app.link/\(action)/wallet?mnemonic=\(mnemonic)") else {
                Logger.shared.error("Invalida url")
                return
            }

            URLHandlingService.shared.handle(url: url)
        }
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
