import Foundation
import Operation_iOS

final class SubtensorPortfolioHistoryLoader {
    let historyStore: SubtensorPriceHistoryStore
    let priceSeriesCache: SubtensorPriceSeriesProviding
    let operationQueue: OperationQueue

    private let callStore = CancellableCallStore()

    init(
        priceHistoryService: SubtensorPriceHistoryServiceProtocol?,
        flowState: SubtensorStakingFlowStateProtocol,
        operationQueue: OperationQueue
    ) {
        priceSeriesCache = flowState.priceSeriesCache
        self.operationQueue = operationQueue

        historyStore = SubtensorPriceHistoryStore(
            priceHistoryService: priceHistoryService,
            historyCache: flowState.priceHistoryCache,
            operationQueue: operationQueue
        )
    }

    deinit {
        callStore.cancel()
    }

    func load(
        for period: SubtensorPricePeriod,
        subnets: [SubtensorSubnetRef],
        taoPriceId: AssetModel.PriceId,
        currency: Currency,
        completion: @escaping (Result<SubtensorPortfolioPriceHistories, Error>) -> Void
    ) {
        callStore.cancel()

        let taoWrapper = priceSeriesCache.createSeriesWrapper(
            for: taoPriceId,
            currency: currency,
            period: period.sourcePeriod.coingeckoPeriod
        )

        let subnetWrappers = subnets.map { subnet in
            historyStore.createHistoryWrapper(for: subnet, period: period, currency: currency)
        }

        let historiesOperation = ClosureOperation<SubtensorPortfolioPriceHistories> {
            let taoHistory = try taoWrapper.targetOperation.extractNoCancellableResultData()

            let histories = subnetWrappers.compactMap { wrapper -> SubtensorPriceHistory? in
                let result = try? wrapper.targetOperation.extractNoCancellableResultData()

                guard case let .available(history) = result else {
                    return nil
                }

                return history
            }

            return SubtensorPortfolioPriceHistories(period: period, taoFiat: taoHistory, subnets: histories)
        }

        historiesOperation.addDependency(taoWrapper.targetOperation)
        subnetWrappers.forEach { historiesOperation.addDependency($0.targetOperation) }

        let wrapper = CompoundOperationWrapper(
            targetOperation: historiesOperation,
            dependencies: taoWrapper.allOperations + subnetWrappers.flatMap(\.allOperations)
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main,
            callbackClosure: completion
        )
    }
}
