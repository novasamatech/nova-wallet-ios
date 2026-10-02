import Foundation
import Operation_iOS

final class SubtensorPositionInteractor: AnyProviderAutoCleaning {
    weak var presenter: SubnetPositionInteractorOutputProtocol?

    let state: SubtensorStakingSharedStateProtocol
    let netuid: UInt16
    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let validatorFactory: SubtensorValidatorPresetFactoryProtocol
    let rootHoldFactory: SubtensorRootHoldFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var priceProvider: StreamableProvider<PriceData>?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var failedHoldsHotkeys: [AccountId]?
    private let catalogueStore = CancellableCallStore()
    private let logosStore = CancellableCallStore()
    private let validatorStore = CancellableCallStore()
    private let rateStore = CancellableCallStore()
    private let holdsStore = CancellableCallStore()
    private let historyStore = CancellableCallStore()

    private var isRoot: Bool {
        netuid == SubtensorStakingPallet.rootNetuid
    }

    private var chainAsset: ChainAsset {
        state.stakingOption.chainAsset
    }

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol {
        state.generalLocalSubscriptionFactory
    }

    init(
        state: SubtensorStakingSharedStateProtocol,
        netuid: UInt16,
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        yieldService: SubtensorYieldServiceProtocol,
        subnetLogosProvider: SubtensorSubnetLogosProviderProtocol,
        priceHistoryService: SubtensorPriceHistoryServiceProtocol?,
        validatorFactory: SubtensorValidatorPresetFactoryProtocol,
        rootHoldFactory: SubtensorRootHoldFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.state = state
        self.netuid = netuid
        self.catalogueService = catalogueService
        self.yieldService = yieldService
        self.subnetLogosProvider = subnetLogosProvider
        self.priceHistoryService = priceHistoryService
        self.validatorFactory = validatorFactory
        self.rootHoldFactory = rootHoldFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
    }

    deinit {
        [catalogueStore, logosStore, validatorStore, rateStore, holdsStore, historyStore].forEach { $0.cancel() }

        state.positionsSyncService?.remove(observer: self)
        state.positionsSyncService?.remove(failureObserver: self)
        state.rootClaimableService?.remove(observer: self)
        state.rootClaimableService?.remove(failureObserver: self)
    }
}

private extension SubtensorPositionInteractor {
    func findGroup(in positionsState: Multistaking.SubtensorStakingState) -> SubtensorPortfolioGroup? {
        let portfolio = SubtensorPortfolioBuilder.build(state: positionsState)
        let group = isRoot ? portfolio.root : portfolio.subnets.first { $0.netuid == netuid }

        return group.flatMap { $0.totalAlpha > 0 ? $0 : nil }
    }

    func subscribePositions() {
        state.positionsSyncService?.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            guard let self, let newState else {
                return
            }

            presenter?.didReceive(group: findGroup(in: newState))
        }

        state.positionsSyncService?.add(
            failureObserver: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, isFailed in
            self?.presenter?.didReceiveSyncFailure(isFailed)
        }
    }

    func subscribeClaimable() {
        guard let claimableService = state.rootClaimableService else {
            presenter?.didReceiveClaimableFailure(true)
            return
        }

        claimableService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, claimable in
            self?.presenter?.didReceive(claimable: claimable)
        }

        claimableService.add(
            failureObserver: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, isFailed in
            self?.presenter?.didReceiveClaimableFailure(isFailed)
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

    func loadSubnetLogos() {
        executeCancellable(
            wrapper: subnetLogosProvider.createLogosWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: logosStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(logos):
                self?.presenter?.didReceive(subnetLogos: logos)
            case let .failure(error):
                self?.logger.warning("Subtensor position subnet mark unavailable: \(error)")
                self?.presenter?.didReceive(subnetLogos: nil)
            }
        }
    }

    func loadRootRate() {
        executeCancellable(
            wrapper: yieldService.createRootYieldWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: rateStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(yield):
                self?.presenter?.didReceive(rootRate: SubtensorAlphaApyFormatter.annualRate(from: yield))
            case let .failure(error):
                self?.logger.warning("Subtensor position root rate unavailable: \(error)")
                self?.presenter?.didReceive(rootRate: nil)
            }
        }
    }

    func loadYields() {
        executeCancellable(
            wrapper: yieldService.createAlphaYieldsWrapper(for: netuid),
            inOperationQueue: operationQueue,
            backingCallIn: rateStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(yields):
                self?.presenter?.didReceive(yields: yields)
            case let .failure(error):
                self?.logger.warning("Subtensor position yields unavailable: \(error)")
                self?.presenter?.didReceive(yields: nil)
            }
        }
    }

    func retryFailedRootHolds() {
        guard let hotkeys = failedHoldsHotkeys else {
            return
        }

        loadRootHolds(for: hotkeys)
    }
}

extension SubtensorPositionInteractor: SubtensorPositionInteractorInputProtocol {
    func setup() {
        subscribePositions()
        subscribePrice()

        if isRoot {
            subscribeClaimable()
            blockNumberProvider = subscribeToBlockNumber(for: chainAsset.chain.chainId)
            loadRootRate()
        } else {
            loadCatalogue()
            loadSubnetLogos()
            loadYields()
            loadSubnetsInfo(forcingRefresh: false)
        }
    }

    func refreshPositions() {
        state.positionsSyncService?.refresh()
    }

    func loadCatalogue() {
        catalogueStore.cancel()

        executeCancellable(
            wrapper: catalogueService.createCatalogueWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: catalogueStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(catalogue):
                self?.presenter?.didReceive(catalogue: catalogue)
            case let .failure(error):
                self?.logger.warning("Subtensor position catalogue unavailable: \(error)")
                self?.presenter?.didReceive(catalogue: nil)
            }
        }
    }

    func loadSubnetsInfo(forcingRefresh: Bool) {
        state.subnetsService.fetchSubnetsInfo(
            forcingRefresh: forcingRefresh,
            runningCompletionIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(subnetsInfo):
                self?.presenter?.didReceive(subnetsInfo: subnetsInfo)
            case let .failure(error):
                self?.logger.warning("Subtensor position subnets unavailable: \(error)")
                self?.presenter?.didReceive(subnetsInfo: nil)
            }
        }
    }

    func loadValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef) {
        validatorStore.cancel()

        executeCancellable(
            wrapper: validatorFactory.createLockedWrapper(for: hotkey, subnet: subnet),
            inOperationQueue: operationQueue,
            backingCallIn: validatorStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(validator):
                self?.presenter?.didReceive(validator: validator, for: hotkey)
            case let .failure(error):
                self?.logger.warning("Subtensor position validator unavailable: \(error)")
                self?.presenter?.didReceive(validator: nil, for: hotkey)
            }
        }
    }

    func loadRootHolds(for hotkeys: [AccountId]) {
        guard let coldkey = state.selectedAccount?.chainAccount.accountId else {
            return
        }

        failedHoldsHotkeys = nil
        holdsStore.cancel()

        executeCancellable(
            wrapper: rootHoldFactory.createHoldsWrapper(coldkey: coldkey, hotkeys: hotkeys),
            inOperationQueue: operationQueue,
            backingCallIn: holdsStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(holds):
                self?.presenter?.didReceive(holds: holds)
            case let .failure(error):
                self?.logger.warning("Subtensor position root holds unavailable: \(error)")
                self?.failedHoldsHotkeys = hotkeys
            }
        }
    }

    func loadHistory(for subnet: SubtensorSubnetRef, period: SubtensorPricePeriod) {
        historyStore.cancel()

        guard let priceHistoryService else {
            presenter?.didReceive(history: .notListed, for: period)
            return
        }

        executeCancellable(
            wrapper: priceHistoryService.createHistoryWrapper(for: subnet, period: period, currency: selectedCurrency),
            inOperationQueue: operationQueue,
            backingCallIn: historyStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(history):
                self?.presenter?.didReceive(history: history, for: period)
            case let .failure(error):
                self?.logger.warning("Subtensor position price history unavailable: \(error)")
                self?.presenter?.didFailHistory(for: period)
            }
        }
    }
}

extension SubtensorPositionInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber {
                presenter?.didReceive(blockNumber: blockNumber)
                retryFailedRootHolds()
            }
        case let .failure(error):
            logger.warning("Subtensor position block number unavailable: \(error)")
        }
    }
}

extension SubtensorPositionInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        guard chainAsset.asset.priceId == priceId else {
            return
        }

        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case let .failure(error):
            logger.error("Subtensor position price unavailable: \(error)")
            presenter?.didReceive(price: nil)
        }
    }
}

extension SubtensorPositionInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        presenter?.didChangeCurrency()
        subscribePrice()
    }
}
