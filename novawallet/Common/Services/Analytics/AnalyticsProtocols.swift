import Foundation
import Operation_iOS

protocol AnalyticsEventQueueProtocol {
    /// Allocates the next sequence, persists the row, then trims to the newest `maxCount`.
    func enqueueWrapper(name: String, timestamp: Date, payload: Data) -> CompoundOperationWrapper<Void>

    /// The oldest `count` rows, in insertion order.
    func peekWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]>

    func dropOperation(ids: [String]) -> BaseOperation<Void>
    func countOperation() -> BaseOperation<Int>
    func clearOperation() -> BaseOperation<Void>
}
