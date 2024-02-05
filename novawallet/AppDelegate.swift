import UIKit
import UserNotifications
import SoraKeystore
import RobinHood

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let operationQueue = OperationQueue()

    var isUnitTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UNITTEST")
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        guard !isUnitTesting else { return true }

        let rootWindow = NovaWindow()
        window = rootWindow

        let presenter = RootPresenterFactory.createPresenter(with: rootWindow)
        presenter.loadOnLaunch()

        // TODO: Remove
        registerForPushNotifications()

        rootWindow.makeKeyAndVisible()
        return true
    }

    private func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            guard granted else { return }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func application(
        _: UIApplication,
        open url: URL,
        options _: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        URLHandlingService.shared.handle(url: url)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        let wrapper: CompoundOperationWrapper<Void>
        if let documentId = SettingsManager.shared.pushSettingsDocumentId {
            let source = PushNotificationsSettingsSource(uuid: documentId)
            wrapper = source.update(token: token)
        } else {
            let uuid = UUID().uuidString
            SettingsManager.shared.pushSettingsDocumentId = uuid
            let source = PushNotificationsSettingsSource(uuid: uuid)
            wrapper = source.save(settings: PushSettings.createDefault(for: token))
        }

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { result in
            switch result {
            case .success:
                Logger.shared.debug("Push token was updated")
            case let .failure(error):
                Logger.shared.error(error.localizedDescription)
            }
        }
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.shared.error(error.localizedDescription)
    }
}
