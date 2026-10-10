import Foundation
import Operation_iOS

final class SubtensorPortfolioHistoryLoader {
    let historyService: SubtensorPortfolioHistoryServiceProtocol
    let priceSeriesCache: SubtensorPriceSeriesProviding
    let operationQueue: OperationQueue

    private let callStore = CancellableCallStore()

    init(
        historyService: SubtensorPortfolioHistoryServiceProtocol,
        flowState: SubtensorStakingFlowStateProtocol,
        operationQueue: OperationQueue
    ) {
        self.historyService = historyService
        priceSeriesCache = flowState.priceSeriesCache
        self.operationQueue = operationQueue
    }

    deinit {
        callStore.cancel()
    }

    func load(
        for period: SubtensorPricePeriod,
        accountSubject: AccountAddress,
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

        let stakeWrapper = historyService.createHistoryWrapper(for: accountSubject, period: period)

        let historiesOperation = ClosureOperation<SubtensorPortfolioPriceHistories> {
            let taoHistory = try taoWrapper.targetOperation.extractNoCancellableResultData()
            let stakeHistory = try stakeWrapper.targetOperation.extractNoCancellableResultData()

            return SubtensorPortfolioPriceHistories(period: period, taoFiat: taoHistory, stake: stakeHistory)
        }

        historiesOperation.addDependency(taoWrapper.targetOperation)
        historiesOperation.addDependency(stakeWrapper.targetOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: historiesOperation,
            dependencies: taoWrapper.allOperations + stakeWrapper.allOperations
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
