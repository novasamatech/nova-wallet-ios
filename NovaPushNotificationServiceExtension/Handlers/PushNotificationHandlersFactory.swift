import Foundation
import Foundation_iOS

enum PushNotificationHandleResult {
    case modified(NotificationContentResult)
    case original(PushNotificationsHandlerErrors)
}

protocol PushNotificationHandler {
    func handle(
        callbackQueue: DispatchQueue?,
        completion: @escaping (PushNotificationHandleResult) -> Void
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
        case let .stakingReward(chainId, payload):
            return StakingRewardsHandler(
                chainId: chainId,
                payload: payload,
                operationQueue: operationQueue
            )
        case let .newMultisig(chainId, payload):
            return NewMultisigHandler(
                chainId: chainId,
                payload: payload,
                operationQueue: operationQueue
            )
        case let .multisigApproval(chainId, payload):
            return MultisigApprovalHandler(
                chainId: chainId,
                payload: payload,
                operationQueue: operationQueue
            )
        case let .multisigExecuted(chainId, payload):
            return MultisigExecutedHandler(
                chainId: chainId,
                payload: payload,
                operationQueue: operationQueue
            )
        case let .multisigCancelled(chainId, payload):
            return MultisigCancelledHandler(
                chainId: chainId,
                payload: payload,
                operationQueue: operationQueue
            )
        }
    }
}

// MARK: Errors

enum PushNotificationsHandlerErrors: Error, Hashable {
    static func == (
        lhs: PushNotificationsHandlerErrors,
        rhs: PushNotificationsHandlerErrors
    ) -> Bool {
        switch (lhs, rhs) {
        case (.chainDisabled, .chainDisabled):
            return true
        case let (.chainNotFound(lhsChainId), .chainNotFound(rhsChainId)):
            return lhsChainId == rhsChainId
        case let (.assetNotFound(lhsAssetId), .assetNotFound(rhsAssetId)):
            return lhsAssetId == rhsAssetId
        case let (.internalError(lhsError), .internalError(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .chainDisabled:
            hasher.combine(0)
        case let .chainNotFound(chainId):
            hasher.combine(1)
            hasher.combine(chainId)
        case let .assetNotFound(assetId):
            hasher.combine(2)
            hasher.combine(assetId)
        case let .internalError(error):
            hasher.combine(3)
            hasher.combine(error.localizedDescription)
        case .undefined:
            hasher.combine(4)
        }
    }

    case chainDisabled
    case chainNotFound(chainId: ChainModel.Id)
    case assetNotFound(assetId: String?)
    case internalError(error: Error)
    case undefined
}
