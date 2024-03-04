import Foundation
import SoraFoundation

protocol PushNotificationHandler {
    func handle(
        callbackQueue: DispatchQueue?,
        completion: @escaping (NotificationContentResult?) -> Void
    )
}

protocol PushNotificationHandlersFactoryProtocol {
    func createHandler(message: NotificationMessage) -> PushNotificationHandler
}

final class PushNotificationHandlersFactory: PushNotificationHandlersFactoryProtocol {
    let operationQueue = OperationQueue()
    lazy var localizationManager: LocalizationManagerProtocol = LocalizationManager.shared

    func createHandler(message: NotificationMessage) -> PushNotificationHandler {
        switch message {
        case let .transfer(type, chainId, payload):
            return TransferHandler(
                chainId: chainId,
                payload: payload,
                type: type,
                operationQueue: operationQueue
            )
        case let .newReferendum(chainId, payload):
            return NewReferendumHandler(
                chainId: chainId,
                payload: payload,
                operationQueue: operationQueue
            )
        case let .referendumUpdate(chainId, payload):
            return ReferendumUpdatesHandler(
                chainId: chainId,
                payload: payload,
                operationQueue: operationQueue
            )
        case let .newRelease(payload):
            return NewReleaseHandler(
                payload: payload,
                localizationManager: localizationManager,
                operationQueue: operationQueue
            )
        default:
            fatalError()
        }
    }
}
