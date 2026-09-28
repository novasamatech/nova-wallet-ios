import Foundation
import Operation_iOS

final class SubtensorPortfolioInteractor: AnyCancellableCleaning {
    weak var presenter: SubnetPortfolioInteractorOutputProtocol?

    let state: SubtensorStakingSharedStateProtocol
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let coingeckoFactory: CoingeckoOperationFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let seriesStore = CancellableCallStore()

    init(
        state: SubtensorStakingSharedStateProtocol,
        currencyManager: CurrencyManagerProtocol,
        coingeckoFactory: CoingeckoOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.state = state
        priceHistoryService = state.earnServices.priceHistoryService
        self.currencyManager = currencyManager
        self.coingeckoFactory = coingeckoFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        seriesStore.cancel()
        state.positionsSyncService?.remove(observer: self)
        state.positionsSyncService?.remove(failureObserver: self)
    }
}

extension SubtensorPortfolioInteractor: SubnetPortfolioInteractorInputProtocol {
    func setup() {
        state.positionsSyncService?.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            if let newState { self?.presenter?.didReceive(state: newState) }
        }
        state.positionsSyncService?.add(
            failureObserver: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, isFailed in
            self?.presenter?.didReceiveSyncFailure(isFailed)
        }
    }

    func refresh() {
        state.positionsSyncService?.refresh()
    }

    func loadSeries(
        portfolio: SubtensorPortfolio,
        subnetsInfo: SubtensorSubnetsInfo?,
        priceId: String?,
        precision: Int16,
        period: SubtensorPricePeriod
    ) {
        seriesStore.cancel()

        guard let priceId else {
            presenter?.didReceive(series: nil)
            return
        }

        let taoOperation = coingeckoFactory.fetchPriceHistory(
            for: priceId,
            currency: currencyManager.selectedCurrency,
            period: period.coingeckoPeriod
        )

        let historyWrappers = createHistoryWrappers(
            for: portfolio,
            subnetsInfo: subnetsInfo,
            period: period
        )

        let operation = ClosureOperation<SubtensorPortfolioValueSeries> {
            let taoHistory = try taoOperation.extractNoCancellableResultData()
            let histories = historyWrappers.compactMap { wrapper -> SubtensorPriceHistory? in
                guard case let .available(history) = try? wrapper.targetOperation
                    .extractNoCancellableResultData() else {
                    return nil
                }
                return history
            }

            return SubtensorPortfolioValueSeriesCalculator.calculate(
                portfolio: portfolio,
                histories: histories,
                taoFiatHistory: taoHistory,
                period: period,
                precision: precision
            )
        }

        operation.addDependency(taoOperation)
        historyWrappers.forEach { operation.addDependency($0.targetOperation) }
        let wrapper = CompoundOperationWrapper(
            targetOperation: operation,
            dependencies: [taoOperation] + historyWrappers.flatMap(\.allOperations)
        )

        executeSeries(wrapper)
    }
}

private extension SubtensorPortfolioInteractor {
    func executeSeries(_ wrapper: CompoundOperationWrapper<SubtensorPortfolioValueSeries>) {
        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: seriesStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(series): self?.presenter?.didReceive(series: series)
            case let .failure(error):
                self?.logger.warning("Bittensor portfolio chart unavailable: \(error)")
                self?.presenter?.didReceive(series: nil)
            }
        }
    }

    func createHistoryWrappers(
        for portfolio: SubtensorPortfolio,
        subnetsInfo: SubtensorSubnetsInfo?,
        period: SubtensorPricePeriod
    ) -> [CompoundOperationWrapper<SubtensorPriceHistoryResult>] {
        portfolio.subnets.compactMap { group in
            subnetsInfo?.subnets.first(where: { $0.netuid == group.netuid }).flatMap { subnet in
                priceHistoryService?.createHistoryWrapper(
                    for: SubtensorSubnetRef(
                        netuid: subnet.netuid,
                        registeredAt: subnet.networkRegisteredAt
                    ),
                    period: period,
                    currency: currencyManager.selectedCurrency
                )
            }
        }
    }
}
