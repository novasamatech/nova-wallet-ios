import Foundation
import Operation_iOS

protocol TransactionTrackingHandleProtocol {
    var key: TransactionTrackingKey { get }
}

protocol TransactionTrackingFacadeProtocol: AnyObject {
    func activate()

    @discardableResult
    func track(_ request: TransactionTrackingRequest) -> TransactionTrackingHandleProtocol
}

protocol ChainTransactionTracking: AnyObject {
    func canTrack(chain: ChainModel) -> Bool

    func startWatch(
        for request: TransactionTrackingRequest,
        chain: ChainModel,
        onResult: @escaping (TransactionWatchResult) -> Void
    ) throws -> TransactionWatching
}

protocol TransactionWatching: AnyObject {
    func checkNow()
    func stop()
}

protocol PendingTransactionPickupProtocol {
    func createRequestsWrapper() -> CompoundOperationWrapper<[TransactionTrackingRequest]>
}

protocol TransactionHistoryResolving {
    func createResolutionWrapper(
        for key: TransactionTrackingKey,
        outcome: TransactionTrackingOutcome
    ) -> CompoundOperationWrapper<Void>
}
