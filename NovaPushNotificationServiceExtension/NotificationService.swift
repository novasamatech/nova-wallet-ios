import UserNotifications
import BigInt
import SoraKeystore
import SoraFoundation

final class NotificationService: UNNotificationServiceExtension {
    typealias ContentHandler = (UNNotificationContent) -> Void
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    var handler: PushNotificationHandler?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping ContentHandler
    ) {
        self.contentHandler = contentHandler
        let requestContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let bestAttemptContent = requestContent else {
            return
        }

        guard let message = try? NotificationMessage(
            userInfo: bestAttemptContent.userInfo,
            decoder: JSONDecoder()
        ) else {
            let result = NotificationContentResult.createUnsupportedResult(
                for: LocalizationManager.shared.selectedLocale
            )
            contentHandler(result.toUserNotificationContent())
            return
        }

        let factory = PushNotificationHandlersFactory()
        handler = factory.createHandler(message: message)

        handler?.handle(callbackQueue: nil) { notification in
            if let notification = notification {
                contentHandler(notification.toUserNotificationContent())
            } else {
                let unsupported = NotificationContentResult.createUnsupportedResult(
                    for: LocalizationManager.shared.selectedLocale
                )
                contentHandler(unsupported.toUserNotificationContent())
            }
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
