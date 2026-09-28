import Foundation
import Operation_iOS

final class SubtensorPositionInteractor: AnyCancellableCleaning {
    weak var presenter: SubnetPositionInteractorOutputProtocol?

    let state: SubtensorStakingSharedStateProtocol
    let netuid: UInt16
    let currencyManager: CurrencyManagerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let historyStore = CancellableCallStore()

    init(
        state: SubtensorStakingSharedStateProtocol,
        netuid: UInt16,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.state = state
        self.netuid = netuid
        self.currencyManager = currencyManager
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        historyStore.cancel()
        state.positionsSyncService?.remove(observer: self)
    }
}

extension SubtensorPositionInteractor: SubtensorPositionInteractorInputProtocol {
    func setup() {
        state.positionsSyncService?.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            guard let self, let newState else { return }
            let portfolio = SubtensorPortfolioBuilder.build(state: newState)
            let groups = [portfolio.root].compactMap { $0 } + portfolio.subnets
            if let group = groups.first(where: { $0.netuid == self.netuid }) {
                presenter?.didReceive(group: group)
            }
        }
    }

    func loadHistory(for subnet: SubtensorSubnetRef, period: SubtensorPricePeriod) {
        historyStore.cancel()
        guard let service = state.earnServices.priceHistoryService else {
            presenter?.didReceive(history: .notListed)
            return
        }

        executeCancellable(
            wrapper: service.createHistoryWrapper(
                for: subnet,
                period: period,
                currency: currencyManager.selectedCurrency
            ),
            inOperationQueue: operationQueue,
            backingCallIn: historyStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(history): self?.presenter?.didReceive(history: history)
            case let .failure(error):
                self?.logger.warning("Position price history unavailable: \(error)")
                self?.presenter?.didReceive(history: .notListed)
            }
        }
    }
}
