import Foundation
import Operation_iOS

/// Every method returns operations for the caller to schedule; the store's own context
/// serialises them. Ordering that matters across *callers* — an enqueue that must be
/// visible to the flush it triggers — is established by `AnalyticsService.trackAndFlush`,
/// not here, which is why this type holds no queue of its own.
final class CoreDataAnalyticsEventQueue {
    private let repository: AnyDataProviderRepository<AnalyticsPendingEvent>
    private let maxCount: Int

    init(
        repository: AnyDataProviderRepository<AnalyticsPendingEvent>,
        maxCount: Int = 500
    ) {
        self.repository = repository
        self.maxCount = maxCount
    }
}

// MARK: - Private

private extension CoreDataAnalyticsEventQueue {
    /// The newest row, or nil when the queue is empty. `reversed: true` inverts the
    /// ascending-by-sequence descriptor the repository was built with.
    func newestRowOperation() -> BaseOperation<[AnalyticsPendingEvent]> {
        repository.fetchOperation(
            by: RepositorySliceRequest(offset: 0, count: 1, reversed: true),
            options: RepositoryFetchOptions()
        )
    }

    /// Rows beyond the newest `maxCount`, newest-first. A single enqueue can overflow by
    /// at most one in steady state, so a window of 50 is ample headroom.
    func overflowOperation() -> BaseOperation<[AnalyticsPendingEvent]> {
        repository.fetchOperation(
            by: RepositorySliceRequest(offset: maxCount, count: 50, reversed: true),
            options: RepositoryFetchOptions()
        )
    }
}

// MARK: - AnalyticsEventQueueProtocol

extension CoreDataAnalyticsEventQueue: AnalyticsEventQueueProtocol {
    func enqueueWrapper(name: String, timestamp: Date, payload: Data) -> CompoundOperationWrapper<Void> {
        let newestOperation = newestRowOperation()

        let saveOperation = repository.saveOperation({
            let newest = try newestOperation.extractNoCancellableResultData().first
            let sequence = (newest?.sequence ?? -1) + 1

            return [
                AnalyticsPendingEvent(
                    identifier: AnalyticsPendingEvent.identifier(for: sequence),
                    sequence: sequence,
                    name: name,
                    timestamp: timestamp,
                    payload: payload
                )
            ]
        }, { [] })

        saveOperation.addDependency(newestOperation)

        let overflowOperation = overflowOperation()
        overflowOperation.addDependency(saveOperation)

        let trimOperation = repository.saveOperation({ [] }, {
            try overflowOperation.extractNoCancellableResultData().map(\.identifier)
        })

        trimOperation.addDependency(overflowOperation)

        return CompoundOperationWrapper(
            targetOperation: trimOperation,
            dependencies: [newestOperation, saveOperation, overflowOperation]
        )
    }

    func peekWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]> {
        let operation = repository.fetchOperation(
            by: RepositorySliceRequest(offset: 0, count: count, reversed: false),
            options: RepositoryFetchOptions()
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func dropOperation(ids: [String]) -> BaseOperation<Void> {
        repository.saveOperation({ [] }, { ids })
    }

    func countOperation() -> BaseOperation<Int> {
        repository.fetchCountOperation()
    }

    func clearOperation() -> BaseOperation<Void> {
        repository.deleteAllOperation()
    }
}
