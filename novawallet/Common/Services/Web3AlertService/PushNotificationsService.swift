import Foundation
import UserNotifications
import UIKit
import FirebaseMessaging
import RobinHood
import SoraKeystore
import SoraFoundation

enum PushNotificationsStatus {
    case authorized
    case on
    case denied
    case notDetermined
}

protocol PushNotificationsServiceProtocol {
    var statusObservable: Observable<PushNotificationsStatus?> { get set }
    func setup()
    func register(completion: @escaping (PushNotificationsStatus) -> Void)
    func updateStatus()
}

final class PushNotificationsService: NSObject, PushNotificationsServiceProtocol {
    let service: Web3AlertsSyncServiceProtocol?
    let settingsManager: SettingsManagerProtocol
    let logger: LoggerProtocol
    var statusObservable: Observable<PushNotificationsStatus?> = .init(state: nil)

    private let notificationCenter = UNUserNotificationCenter.current()
    private let applicationHandler: ApplicationHandlerProtocol

    init(
        service: Web3AlertsSyncServiceProtocol?,
        settingsManager: SettingsManagerProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        logger: LoggerProtocol
    ) {
        self.service = service
        self.settingsManager = settingsManager
        self.applicationHandler = applicationHandler
        self.logger = logger
    }

    private func register(
        withOptions options: UNAuthorizationOptions,
        completion: @escaping (PushNotificationsStatus) -> Void
    ) {
        notificationCenter.requestAuthorization(options: options) { [weak self] granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            if let error = error {
                self?.logger.error(error.localizedDescription)
            }
            self?.status { [weak self] newStatus in
                self?.statusObservable.state = newStatus
                completion(newStatus)
            }
        }
    }

    private func status(completion: @escaping (PushNotificationsStatus) -> Void) {
        let notificationsEnabled = settingsManager.notificationsEnabled
        notificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                if notificationsEnabled {
                    completion(.on)
                } else {
                    completion(.authorized)
                }
            case .denied, .ephemeral:
                completion(.denied)
            case .notDetermined:
                completion(.notDetermined)
            }
        }
    }

    func setup() {
        Messaging.messaging().delegate = self
        notificationCenter.delegate = self
        applicationHandler.delegate = self
        updateStatus()
    }

    func register(completion: @escaping (PushNotificationsStatus) -> Void) {
        register(withOptions: [.alert, .badge, .sound]) { status in
            completion(status)
        }
    }

    func updateStatus() {
        status { [weak self] newStatus in
            self?.statusObservable.state = newStatus
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

extension PushNotificationsService: ApplicationHandlerDelegate {
    func didReceiveWillEnterForeground(notification _: Notification) {
        updateStatus()
    }
}
