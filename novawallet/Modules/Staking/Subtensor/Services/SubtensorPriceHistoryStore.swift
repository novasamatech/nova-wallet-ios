import Foundation
import Operation_iOS

final class SubtensorPriceHistoryStore {
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let historyCache: SubtensorPriceHistoryCaching
    let operationQueue: OperationQueue

    init(
        priceHistoryService: SubtensorPriceHistoryServiceProtocol?,
        historyCache: SubtensorPriceHistoryCaching,
        operationQueue: OperationQueue
    ) {
        self.priceHistoryService = priceHistoryService
        self.historyCache = historyCache
        self.operationQueue = operationQueue
    }

    convenience init(state: SubtensorStakingSharedStateProtocol, operationQueue: OperationQueue) {
        self.init(
            priceHistoryService: state.earnServices.priceHistoryService,
            historyCache: state.flowState.priceHistoryCache,
            operationQueue: operationQueue
        )
    }

    func loadHistory(
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency,
        backingCallIn callStore: CancellableCallStore,
        completion: @escaping (Result<SubtensorPriceHistoryResult, Error>) -> Void
    ) {
        callStore.cancel()

        if let history = historyCache.history(for: subnet, period: period, currency: currency) {
            completion(.success(history))
            return
        }

        executeCancellable(
            wrapper: createHistoryWrapper(for: subnet, period: period, currency: currency),
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main,
            callbackClosure: completion
        )
    }

    func createHistoryWrapper(
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency
    ) -> CompoundOperationWrapper<SubtensorPriceHistoryResult> {
        guard let priceHistoryService else {
            return .createWithResult(.notListed)
        }

        if let history = historyCache.history(for: subnet, period: period, currency: currency) {
            return .createWithResult(history)
        }

        let entryWrapper = priceHistoryService.createHistoryEntryWrapper(
            for: subnet,
            period: period,
            currency: currency
        )
        let historyCache = historyCache

        let storeOperation = ClosureOperation<SubtensorPriceHistoryResult> {
            let entry = try entryWrapper.targetOperation.extractNoCancellableResultData()

            historyCache.store(entry, for: subnet, period: period, currency: currency)

            return entry.result
        }

        storeOperation.addDependency(entryWrapper.targetOperation)

        return entryWrapper.insertingTail(operation: storeOperation)
    }
}
