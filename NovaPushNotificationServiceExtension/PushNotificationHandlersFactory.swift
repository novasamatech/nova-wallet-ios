import Foundation

protocol PushNotificationHandler {
    func handle(callbackQueue: DispatchQueue?,
                completion: @escaping (NotificationContentResult?) -> Void)
}

protocol PushNotificationHandlersFactoryProtocol {
    func createHandler(message: NotificationMessage) -> PushNotificationHandler
}

final class PushNotificationHandlersFactory: PushNotificationHandlersFactoryProtocol {
    func createHandler(message: NotificationMessage) -> PushNotificationHandler {
        switch message {
        case .transfer(let type, let chainId, let payload):
            return TransferHandler(chainId: chainId,
                                   payload: payload,
                                   type: type)
        }
    }
}

