import Foundation
import Operation_iOS

public final class CoreDataAnalyticsEventQueue {
    private let repository: AnyDataProviderRepository<AnalyticsPendingEvent>
    private let maxCount: Int

    public init(
        repository: AnyDataProviderRepository<AnalyticsPendingEvent>,
        maxCount: Int = 500
    ) {
        self.repository = repository
        self.maxCount = maxCount
    }
}

// MARK: - Private

private extension CoreDataAnalyticsEventQueue {
    func newestRowOperation() -> BaseOperation<[AnalyticsPendingEvent]> {
        repository.fetchOperation(
            by: RepositorySliceRequest(offset: 0, count: 1, reversed: true),
            options: RepositoryFetchOptions()
        )
    }

    func overflowOperation() -> BaseOperation<[AnalyticsPendingEvent]> {
        repository.fetchOperation(
            by: RepositorySliceRequest(offset: maxCount, count: 50, reversed: true),
            options: RepositoryFetchOptions()
        )
    }
}

// MARK: - AnalyticsEventQueueProtocol

extension CoreDataAnalyticsEventQueue: AnalyticsEventQueueProtocol {
    public func enqueueWrapper(name: String, timestamp: Date, payload: Data) -> CompoundOperationWrapper<Void> {
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

    public func peekWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]> {
        let operation = repository.fetchOperation(
            by: RepositorySliceRequest(offset: 0, count: count, reversed: false),
            options: RepositoryFetchOptions()
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }

    public func dropOperation(ids: [String]) -> BaseOperation<Void> {
        repository.saveOperation({ [] }, { ids })
    }

    public func countOperation() -> BaseOperation<Int> {
        repository.fetchCountOperation()
    }

    public func clearOperation() -> BaseOperation<Void> {
        repository.deleteAllOperation()
    }
}
