import UserNotifications
import BigInt
import Keystore_iOS
import Foundation_iOS

final class NotificationService: UNNotificationServiceExtension {
    typealias ContentHandler = (UNNotificationContent) -> Void
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    var handler: PushNotificationHandler?
    var logger = Logger.shared

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping ContentHandler
    ) {
        self.contentHandler = contentHandler
        let requestContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let bestAttemptContent = requestContent else {
            return
        }

        LocalizationManager.shared.refreshLocale()

        guard let message = try? NotificationMessage(
            userInfo: bestAttemptContent.userInfo,
            decoder: JSONDecoder()
        ) else {
            contentHandler(bestAttemptContent)
            return
        }

        let factory = PushNotificationHandlersFactory()
        handler = factory.createHandler(message: message)

        handler?.handle(callbackQueue: nil) { [weak self] handlerResult in
            switch handlerResult {
            case let .modified(notification):
                contentHandler(notification.toUserNotificationContent(with: bestAttemptContent))
            case let .original(error):
                self?.logError(error)
                contentHandler(UNNotificationContent())
            }
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func logError(_ error: PushNotificationsHandlerErrors) {
        switch error {
        case let .assetNotFound(assetId):
            logger.error("Notification handler failed to find asset with id: \(assetId ?? "")")
        case let .chainNotFound(chainId):
            logger.error("Notification handler failed to find asset with id: \(chainId)")
        case let .internalError(error):
            logger.error("Notification handler failed with error: \(error.localizedDescription)")
        case .undefined:
            logger.error("Notification handler failed with undefined reason")
        default:
            break
        }
    }
}
