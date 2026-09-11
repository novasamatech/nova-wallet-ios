import Foundation
import Operation_iOS
@testable import NovaAnalytics

final class AnalyticsEventQueueClearInterceptor {
    var clearError: Error?
    var onClearScheduled: (() -> Void)?

    private let wrapped: AnalyticsEventQueueProtocol
    private let recordedClearCalls = Locked(0)

    var clearCallCount: Int { recordedClearCalls.value }

    init(wrapping wrapped: AnalyticsEventQueueProtocol) {
        self.wrapped = wrapped
    }
}

extension AnalyticsEventQueueClearInterceptor: AnalyticsEventQueueProtocol {
    func enqueueWrapper(
        name: String,
        timestamp: Date,
        payload: Data,
        consentEpoch: Int
    ) -> CompoundOperationWrapper<Void> {
        wrapped.enqueueWrapper(name: name, timestamp: timestamp, payload: payload, consentEpoch: consentEpoch)
    }

    func peekWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]> {
        wrapped.peekWrapper(count: count)
    }

    func dropOperation(ids: [String]) -> BaseOperation<Void> {
        wrapped.dropOperation(ids: ids)
    }

    func countOperation() -> BaseOperation<Int> {
        wrapped.countOperation()
    }

    func clearOperation() -> BaseOperation<Void> {
        onClearScheduled?()

        let error = clearError
        let calls = recordedClearCalls
        let deletion = wrapped.clearOperation()

        return ClosureOperation {
            calls.update { $0 += 1 }

            if let error {
                throw error
            }

            OperationQueue().addOperations([deletion], waitUntilFinished: true)

            try deletion.extractNoCancellableResultData()
        }
    }
}
