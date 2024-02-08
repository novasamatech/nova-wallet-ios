import Foundation
import UserNotifications
import UIKit
import FirebaseMessaging
import RobinHood

protocol PushNotificationsServiceProtocol {
    func register()
    func update(deviceToken: Data)
}

final class PushNotificationsService: NSObject, PushNotificationsServiceProtocol {
    let service: Web3AlertsSyncServiceProtocol
    let logger: LoggerProtocol
    let callStore = CancellableCallStore()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let operationQueue: OperationQueue

    init(
        service: Web3AlertsSyncServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.service = service
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func register(withOptions options: UNAuthorizationOptions) {
        Messaging.messaging().delegate = self
        notificationCenter.delegate = self
        notificationCenter.requestAuthorization(options: options) {
            granted, _ in
            guard granted else { return }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func register() {
        register(withOptions: [.alert, .badge, .sound])
    }

    func update(deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

extension PushNotificationsService: MessagingDelegate {
    func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        let wrapper = service.update(token: fcmToken ?? "")

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: nil
        ) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Push token was updated")
            case let .failure(error):
                self?.logger.error(error.localizedDescription)
            }
        }
    }
}

extension PushNotificationsService: UNUserNotificationCenterDelegate {
    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().delegate = self
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error(error.localizedDescription)
    }
}
