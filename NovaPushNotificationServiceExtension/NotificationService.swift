import UserNotifications
import BigInt
import SoraKeystore

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
            contentHandler(request.content)
            return
        }

        guard let message = try? NotificationMessage(
            userInfo: bestAttemptContent.userInfo,
            decoder: JSONDecoder()
        ) else {
            contentHandler(request.content)
            return
        }

        let factory = PushNotificationHandlersFactory()
        handler = factory.createHandler(message: message)

        handler?.handle(callbackQueue: nil) { notification in
            bestAttemptContent.title = notification?.title ?? ""
            bestAttemptContent.subtitle = ""
            bestAttemptContent.body = notification?.subtitle ?? ""
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
