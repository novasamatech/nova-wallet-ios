import Foundation
import Operation_iOS

final class SubtensorSubnetDetailsInteractor: AnyCancellableCleaning {
    weak var presenter: SubnetDetailsInteractorOutputProtocol?

    private let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    private let recommendationService: SubtensorRecommendationServiceProtocol?
    private let currencyManager: CurrencyManagerProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol
    private let historyStore = CancellableCallStore()
    private let riskStore = CancellableCallStore()

    init(
        priceHistoryService: SubtensorPriceHistoryServiceProtocol?,
        recommendationService: SubtensorRecommendationServiceProtocol?,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.priceHistoryService = priceHistoryService
        self.recommendationService = recommendationService
        self.currencyManager = currencyManager
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        historyStore.cancel()
        riskStore.cancel()
    }
}

extension SubtensorSubnetDetailsInteractor: SubnetDetailsInteractorInputProtocol {
    func loadHistory(for subnet: SubtensorSubnetRef, period: SubtensorPricePeriod) {
        historyStore.cancel()

        guard let priceHistoryService else {
            presenter?.didReceive(history: .notListed)
            return
        }

        let wrapper = priceHistoryService.createHistoryWrapper(
            for: subnet,
            period: period,
            currency: currencyManager.selectedCurrency
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: historyStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(history):
                self?.presenter?.didReceive(history: history)
            case let .failure(error):
                self?.logger.warning("Subnet price history unavailable: \(error)")
                self?.presenter?.didFailHistory(error)
            }
        }
    }

    func loadRisk(for netuid: UInt16) {
        riskStore.cancel()

        guard let recommendationService else {
            presenter?.didReceive(risk: nil)
            return
        }

        executeCancellable(
            wrapper: recommendationService.createRankedSubnetsWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: riskStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(ranked):
                self?.presenter?.didReceive(risk: ranked.items.first { $0.netuid == netuid })
            case let .failure(error):
                self?.logger.warning("Subnet risk information unavailable: \(error)")
                self?.presenter?.didReceive(risk: nil)
            }
        }
    }
}
