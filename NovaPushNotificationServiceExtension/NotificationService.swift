import UserNotifications
import BigInt
import SoraKeystore

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    var handler: PushNotificationHandler?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        
        guard let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            return
        }
        guard let messageData = bestAttemptContent.userInfo["data"] as? Data,
              let message = try? JSONDecoder().decode(NotificationMessage.self, from: messageData) else {
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
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
