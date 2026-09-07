import Foundation
import Operation_iOS
@testable import NovaAnalytics

final class AnalyticsEventQueueClearInterceptor {
    var clearError: Error?
    var onClear: (() -> Void)?

    private let wrapped: AnalyticsEventQueueProtocol
    private let mutex = NSLock()
    private var recordedClearCalls = 0

    var clearCallCount: Int {
        synchronised { recordedClearCalls }
    }

    init(wrapping wrapped: AnalyticsEventQueueProtocol) {
        self.wrapped = wrapped
    }

    private func synchronised<T>(_ body: () -> T) -> T {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return body()
    }
}

extension AnalyticsEventQueueClearInterceptor: AnalyticsEventQueueProtocol {
    func enqueueWrapper(name: String, timestamp: Date, payload: Data) -> CompoundOperationWrapper<Void> {
        wrapped.enqueueWrapper(name: name, timestamp: timestamp, payload: payload)
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
        let error = clearError
        let hook = onClear
        let deletion = wrapped.clearOperation()

        return ClosureOperation { [weak self] in
            self?.synchronised { self?.recordedClearCalls += 1 }
            hook?()

            if let error {
                throw error
            }

            OperationQueue().addOperations([deletion], waitUntilFinished: true)

            try deletion.extractNoCancellableResultData()
        }
    }
}
