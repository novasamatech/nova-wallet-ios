import Foundation
import Operation_iOS

final class SubtensorPositionInteractor: AnyProviderAutoCleaning {
    weak var presenter: SubnetPositionInteractorOutputProtocol?

    let state: SubtensorStakingSharedStateProtocol
    let netuid: UInt16
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var priceProvider: StreamableProvider<PriceData>?
    private let historyStore = CancellableCallStore()

    private var chainAsset: ChainAsset {
        state.stakingOption.chainAsset
    }

    init(
        state: SubtensorStakingSharedStateProtocol,
        netuid: UInt16,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.state = state
        self.netuid = netuid
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
    }

    deinit {
        historyStore.cancel()
        state.positionsSyncService?.remove(observer: self)
        state.rootClaimableService?.remove(observer: self)
    }
}

extension SubtensorPositionInteractor: SubtensorPositionInteractorInputProtocol {
    func setup() {
        subscribePositions()
        subscribeClaimable()
        subscribePrice()
        provideSubnetsInfo()
        provideDelegates()
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
                currency: selectedCurrency
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

private extension SubtensorPositionInteractor {
    func subscribePositions() {
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

    func subscribeClaimable() {
        state.rootClaimableService?.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, claimable in
            self?.presenter?.didReceive(claimable: claimable)
        }
    }

    func subscribePrice() {
        clear(streamableProvider: &priceProvider)

        guard let priceId = chainAsset.asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func provideSubnetsInfo() {
        state.subnetsService.fetchSubnetsInfo(runningCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(subnetsInfo):
                self?.presenter?.didReceive(subnetsInfo: subnetsInfo)
            case let .failure(error):
                self?.logger.error("Position subnets unavailable: \(error)")
            }
        }
    }

    func provideDelegates() {
        state.delegatesService.fetchDelegates(runningCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(delegates):
                self?.presenter?.didReceive(delegates: delegates)
            case let .failure(error):
                self?.logger.error("Position delegates unavailable: \(error)")
            }
        }
    }
}

extension SubtensorPositionInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        guard chainAsset.asset.priceId == priceId else { return }

        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case let .failure(error):
            logger.error("Position price unavailable: \(error)")
        }
    }
}

extension SubtensorPositionInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else { return }

        subscribePrice()
    }
}
