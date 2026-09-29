import Foundation
import Operation_iOS

final class SubtensorPortfolioHistoryLoader {
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let coingeckoFactory: CoingeckoOperationFactoryProtocol
    let operationQueue: OperationQueue

    private var historyCache: [HistoryKey: SubtensorPriceHistoryResult] = [:]
    private var taoHistoryCache: [TaoHistoryKey: PriceHistory] = [:]
    private let callStore = CancellableCallStore()

    init(
        priceHistoryService: SubtensorPriceHistoryServiceProtocol?,
        coingeckoFactory: CoingeckoOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.priceHistoryService = priceHistoryService
        self.coingeckoFactory = coingeckoFactory
        self.operationQueue = operationQueue
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

        let taoKey = TaoHistoryKey(period: period, currencyId: currency.id)

        let taoWrapper = taoHistoryCache[taoKey].map { CompoundOperationWrapper.createWithResult($0) } ??
            CompoundOperationWrapper(
                targetOperation: coingeckoFactory.fetchPriceHistory(
                    for: taoPriceId,
                    currency: currency,
                    period: period.coingeckoPeriod
                )
            )

        let subnetWrappers = createMissingWrappers(for: subnets, period: period, currency: currency)

        let fetchOperation = ClosureOperation<Fetch> {
            let taoHistory = try taoWrapper.targetOperation.extractNoCancellableResultData()

            let subnetHistories = subnetWrappers.reduce(
                into: [SubtensorSubnetRef: SubtensorPriceHistoryResult]()
            ) { result, item in
                result[item.subnet] = try? item.wrapper.targetOperation.extractNoCancellableResultData()
            }

            return Fetch(taoHistory: taoHistory, subnetHistories: subnetHistories)
        }

        fetchOperation.addDependency(taoWrapper.targetOperation)
        subnetWrappers.forEach { fetchOperation.addDependency($0.wrapper.targetOperation) }

        let wrapper = CompoundOperationWrapper(
            targetOperation: fetchOperation,
            dependencies: taoWrapper.allOperations + subnetWrappers.flatMap(\.wrapper.allOperations)
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else {
                return
            }

            completion(
                result.map { fetch in
                    self.store(fetch, period: period, subnets: subnets, currencyId: currency.id)
                }
            )
        }
    }
}

private extension SubtensorPortfolioHistoryLoader {
    struct HistoryKey: Hashable {
        let subnet: SubtensorSubnetRef
        let period: SubtensorPricePeriod
        let currencyId: Int
    }

    struct TaoHistoryKey: Hashable {
        let period: SubtensorPricePeriod
        let currencyId: Int
    }

    struct SubnetWrapper {
        let subnet: SubtensorSubnetRef
        let wrapper: CompoundOperationWrapper<SubtensorPriceHistoryResult>
    }

    struct Fetch {
        let taoHistory: PriceHistory
        let subnetHistories: [SubtensorSubnetRef: SubtensorPriceHistoryResult]
    }

    func createMissingWrappers(
        for subnets: [SubtensorSubnetRef],
        period: SubtensorPricePeriod,
        currency: Currency
    ) -> [SubnetWrapper] {
        guard let priceHistoryService else {
            return []
        }

        return subnets
            .filter { historyCache[HistoryKey(subnet: $0, period: period, currencyId: currency.id)] == nil }
            .map { subnet in
                SubnetWrapper(
                    subnet: subnet,
                    wrapper: priceHistoryService.createHistoryWrapper(for: subnet, period: period, currency: currency)
                )
            }
    }

    func store(
        _ fetch: Fetch,
        period: SubtensorPricePeriod,
        subnets: [SubtensorSubnetRef],
        currencyId: Int
    ) -> SubtensorPortfolioPriceHistories {
        taoHistoryCache[TaoHistoryKey(period: period, currencyId: currencyId)] = fetch.taoHistory

        fetch.subnetHistories.forEach { subnet, history in
            historyCache[HistoryKey(subnet: subnet, period: period, currencyId: currencyId)] = history
        }

        let histories = subnets.compactMap { subnet -> SubtensorPriceHistory? in
            let key = HistoryKey(subnet: subnet, period: period, currencyId: currencyId)

            guard case let .available(history) = historyCache[key] else {
                return nil
            }

            return history
        }

        return SubtensorPortfolioPriceHistories(period: period, taoFiat: fetch.taoHistory, subnets: histories)
    }
}
