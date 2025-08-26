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
            TransferHandler(
                chainId: chainId,
                payload: payload,
                type: type,
                operationQueue: operationQueue
            )
        case let .newReferendum(chainId, payload):
            NewReferendumHandler(
                chainId: chainId,
                payload: payload,
                operationQueue: operationQueue
            )
        case let .referendumUpdate(chainId, payload):
            ReferendumUpdatesHandler(
                chainId: chainId,
                payload: payload,
                operationQueue: operationQueue
            )
        case let .newRelease(payload):
            NewReleaseHandler(
                payload: payload,
                localizationManager: localizationManager,
                operationQueue: operationQueue
            )
        case let .stakingReward(chainId, payload):
            StakingRewardsHandler(
                chainId: chainId,
                payload: payload,
                operationQueue: operationQueue
            )
        case let .newMultisig(chainId, payload):
            NewMultisigHandler(
                chainId: chainId,
                payload: payload,
                operationQueue: operationQueue
            )
        case let .multisigApproval(chainId, payload):
            MultisigApprovalHandler(
                chainId: chainId,
                payload: payload,
                operationQueue: operationQueue
            )
        case let .multisigExecuted(chainId, payload):
            MultisigExecutedHandler(
                chainId: chainId,
                payload: payload,
                operationQueue: operationQueue
            )
        case let .multisigCancelled(chainId, payload):
            MultisigCancelledHandler(
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
            true
        case let (.chainNotFound(lhsChainId), .chainNotFound(rhsChainId)):
            lhsChainId == rhsChainId
        case let (.assetNotFound(lhsAssetId), .assetNotFound(rhsAssetId)):
            lhsAssetId == rhsAssetId
        case let (.internalError(lhsError), .internalError(rhsError)):
            lhsError.localizedDescription == rhsError.localizedDescription
        case (.targetWalletNotFound, .targetWalletNotFound):
            true
        default:
            false
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
        case .targetWalletNotFound:
            hasher.combine(4)
        case .undefined:
            hasher.combine(5)
        }
    }

    case chainDisabled
    case chainNotFound(chainId: ChainModel.Id)
    case assetNotFound(assetId: String?)
    case internalError(error: Error)
    case targetWalletNotFound
    case undefined
}
