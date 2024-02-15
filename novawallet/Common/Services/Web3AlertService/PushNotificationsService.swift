import Foundation
import UserNotifications
import UIKit
import FirebaseMessaging
import RobinHood
import SoraKeystore

enum PushNotificationsStatus {
    case on
    case off
    case notDetermined
}

protocol PushNotificationsServiceProtocol {
    func setup()
    func register(completion: @escaping () -> Void)
    func status(completion: @escaping (PushNotificationsStatus) -> Void)
}

final class PushNotificationsService: NSObject, PushNotificationsServiceProtocol {
    let service: Web3AlertsSyncServiceProtocol?
    let settingsManager: SettingsManagerProtocol
    let logger: LoggerProtocol
    private let notificationCenter = UNUserNotificationCenter.current()

    init(
        service: Web3AlertsSyncServiceProtocol?,
        settingsManager: SettingsManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.service = service
        self.settingsManager = settingsManager
        self.logger = logger
    }

    private func register(withOptions options: UNAuthorizationOptions, completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: options) { [weak self] granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            if let error = error {
                self?.logger.error(error.localizedDescription)
            }
            completion(granted)
        }
    }

    func status(completion: @escaping (PushNotificationsStatus) -> Void) {
        let notificationsEnabled = settingsManager.notificationsEnabled
        notificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                completion(notificationsEnabled ? .on : .off)
            case .denied, .ephemeral:
                completion(.off)
            case .notDetermined:
                completion(.notDetermined)
            }
        }
    }

    func setup() {
        Messaging.messaging().delegate = self
        notificationCenter.delegate = self
    }

    func register(completion: @escaping () -> Void) {
        register(withOptions: [.alert, .badge, .sound]) { [weak self] _ in
            completion()
        }
    }
}

extension PushNotificationsService: MessagingDelegate {
    func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        service?.update(token: fcmToken ?? "") { [weak self] in
            self?.logger.debug("Push token was updated")
        }
    }
}

extension PushNotificationsService: UNUserNotificationCenterDelegate {
    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error(error.localizedDescription)
    }
}
