import Foundation
import UserNotifications
import UIKit
import FirebaseMessaging
import RobinHood
import SoraKeystore
import SoraFoundation

enum PushNotificationsStatus {
    case authorized
    case active
    case denied
    case notDetermined
    case unknown

    static var userInitiatedStatuses: Set<PushNotificationsStatus> {
        [.active, .authorized, .denied]
    }
}

protocol PushNotificationsStatusServiceProtocol: AnyObject, ApplicationServiceProtocol {
    var delegate: PushNotificationsStatusServiceDelegate? { get set }

    var statusObservable: Observable<PushNotificationsStatus> { get }

    func register()
    func deregister()

    func enablePushNotifications()
    func disablePushNotifications()

    func updateAPNS(token: Data)

    func notificationsReadyOperation(with timeoutInSec: Int) -> BaseOperation<Void>
}

protocol PushNotificationsStatusServiceDelegate: AnyObject {
    func didReceivePushNotifications(token: String)
}

enum PushNotificationsStatusServiceError: Error {
    case notifcationTokensWaitDenied
    case notifcationTokensWaitTimeout
}

// This class is desinged to be accessed only from the main thread
final class PushNotificationsStatusService: NSObject {
    enum TokensReadyStatus {
        case waiting
        case denied
        case ready
    }

    let settingsManager: SettingsManagerProtocol
    let logger: LoggerProtocol
    let statusObservable: Observable<PushNotificationsStatus> = .init(state: .unknown)
    let tokensReadyObservable: Observable<TokensReadyStatus> = .init(state: .waiting)

    private let notificationCenter = UNUserNotificationCenter.current()
    private let applicationHandler: ApplicationHandlerProtocol

    weak var delegate: PushNotificationsStatusServiceDelegate?

    init(
        settingsManager: SettingsManagerProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        logger: LoggerProtocol
    ) {
        self.settingsManager = settingsManager
        self.applicationHandler = applicationHandler
        self.logger = logger
    }

    private func status(with completion: @escaping (PushNotificationsStatus) -> Void) {
        let notificationsEnabled = settingsManager.notificationsEnabled
        notificationCenter.getNotificationSettings { settings in
            dispatchInQueueWhenPossible(.main) {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    if notificationsEnabled {
                        completion(.active)
                    } else {
                        completion(.authorized)
                    }
                case .denied, .ephemeral:
                    completion(.denied)
                case .notDetermined:
                    completion(.notDetermined)
                @unknown default:
                    completion(.notDetermined)
                }
            }
        }
    }

    private func updateTokensReadyState() {
        switch statusObservable.state {
        case .active:
            let messaging = Messaging.messaging()
            let hasApns = messaging.apnsToken != nil
            let hasFcm = messaging.fcmToken != nil
            tokensReadyObservable.state = hasApns && hasFcm ? .ready : .waiting
        case .denied:
            tokensReadyObservable.state = .denied
        case .authorized, .notDetermined, .unknown:
            tokensReadyObservable.state = .waiting
        }
    }

    private func syncSettingsIfNeeded(newStatus: PushNotificationsStatus) {
        if newStatus == .denied, settingsManager.notificationsEnabled {
            settingsManager.notificationsEnabled = false
        }
    }

    private func updateStatus() {
        status { [weak self] newStatus in
            self?.syncSettingsIfNeeded(newStatus: newStatus)
            self?.statusObservable.state = newStatus
            self?.updateTokensReadyState()
        }
    }

    private func setupNotificationDelegates() {
        Messaging.messaging().delegate = self
        notificationCenter.delegate = self
    }

    private func clearNotificationDelegates() {
        Messaging.messaging().delegate = nil
        notificationCenter.delegate = nil
    }
}

extension PushNotificationsStatusService: PushNotificationsStatusServiceProtocol {
    func setup() {
        applicationHandler.delegate = self
        updateStatus()
    }

    func throttle() {
        applicationHandler.delegate = nil

        if settingsManager.notificationsEnabled {
            clearNotificationDelegates()
        }
    }

    func register() {
        setupNotificationDelegates()

        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            dispatchInQueueWhenPossible(.main) {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }

                self?.updateStatus()
            }
        }
    }

    func deregister() {
        Messaging.messaging().deleteToken { [weak self] optError in
            if let error = optError {
                self?.logger.error("FCM token remove failed: \(error)")
            } else {
                self?.logger.error("FCM token removed")
            }

            self?.updateStatus()
        }
    }

    func enablePushNotifications() {
        guard !settingsManager.notificationsEnabled else {
            return
        }

        settingsManager.notificationsEnabled = true

        register()
    }

    func disablePushNotifications() {
        guard settingsManager.notificationsEnabled else {
            return
        }

        settingsManager.notificationsEnabled = false

        deregister()
    }

    func updateAPNS(token: Data) {
        Messaging.messaging().apnsToken = token

        updateTokensReadyState()
    }

    func notificationsReadyOperation(with timeoutInSec: Int) -> BaseOperation<Void> {
        ClosureOperation {
            let semaphore = DispatchSemaphore(value: 0)

            let subscriptionId = NSObject()

            var error: PushNotificationsStatusServiceError?

            dispatchInQueueWhenPossible(.main) {
                self.tokensReadyObservable.addObserver(
                    with: subscriptionId,
                    sendStateOnSubscription: true,
                    queue: .main
                ) { _, status in
                    switch status {
                    case .ready:
                        error = nil
                        semaphore.signal()
                    case .denied:
                        error = .notifcationTokensWaitDenied
                        semaphore.signal()
                    case .waiting:
                        break
                    }
                }
            }

            let status = semaphore.wait(timeout: .now() + .seconds(timeoutInSec))

            dispatchInQueueWhenPossible(.main) {
                self.tokensReadyObservable.removeObserver(by: subscriptionId)
            }

            switch status {
            case .success:
                if let error = error {
                    throw error
                }
            case .timedOut:
                throw PushNotificationsStatusServiceError.notifcationTokensWaitTimeout
            }
        }
    }
}

extension PushNotificationsStatusService: MessagingDelegate {
    func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let fcmToken = fcmToken {
            logger.debug("Did receive push token")
            delegate?.didReceivePushNotifications(token: fcmToken)
        } else {
            logger.warning("Did receive empty push token")
        }

        updateTokensReadyState()
    }
}

extension PushNotificationsStatusService: ApplicationHandlerDelegate {
    func didReceiveWillEnterForeground(notification _: Notification) {
        updateStatus()
    }
}

extension PushNotificationsStatusService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
}
