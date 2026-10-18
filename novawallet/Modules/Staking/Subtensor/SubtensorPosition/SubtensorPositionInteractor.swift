import Foundation
import Foundation_iOS
import Operation_iOS

final class SubtensorPositionInteractor: AnyProviderAutoCleaning, SubtensorLoadDelivering {
    weak var presenter: SubnetPositionInteractorOutputProtocol?

    let state: SubtensorStakingSharedStateProtocol
    let netuid: UInt16
    let alphaPriceProvider: SubtensorAlphaPriceProviderProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let validatorFactory: SubtensorValidatorPresetFactoryProtocol
    let rootHoldFactory: SubtensorRootHoldFactoryProtocol
    let blockNumberSubscription: BlockNumberRemoteSubscriptionProtocol?
    let applicationHandler: ApplicationHandlerProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    var priceProvider: StreamableProvider<PriceData>?
    private var failedHoldsHotkeys: [AccountId]?
    private var isBlockFeedDown = false
    private let pricesStore = CancellableCallStore()
    private let logosStore = CancellableCallStore()
    private let validatorStore = CancellableCallStore()
    private let rateStore = CancellableCallStore()
    private let holdsStore = CancellableCallStore()
    private let historyStore = CancellableCallStore()
    private let subnetsInfoStore = CancellableCallStore()

    private var isRoot: Bool {
        netuid == SubtensorStakingPallet.rootNetuid
    }

    var chainAsset: ChainAsset {
        state.stakingOption.chainAsset
    }

    init(
        state: SubtensorStakingSharedStateProtocol,
        netuid: UInt16,
        blockNumberSubscription: BlockNumberRemoteSubscriptionProtocol?,
        applicationHandler: ApplicationHandlerProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.state = state
        self.netuid = netuid
        alphaPriceProvider = state.earnServices.alphaPriceProvider
        yieldService = state.earnServices.yieldService
        subnetLogosProvider = state.earnServices.subnetLogosProvider
        priceHistoryService = state.earnServices.priceHistoryService
        validatorFactory = state.earnServices.validatorPresetFactory
        rootHoldFactory = state.earnServices.rootHoldFactory
        self.blockNumberSubscription = blockNumberSubscription
        self.applicationHandler = applicationHandler
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
    }

    deinit {
        [pricesStore, logosStore, validatorStore, rateStore, holdsStore, historyStore, subnetsInfoStore].forEach {
            $0.cancel()
        }

        blockNumberSubscription?.unsubscribe()
        state.positionsSyncService?.remove(observer: self)
    }
}

private extension SubtensorPositionInteractor {
    func findGroup(in positionsState: Multistaking.SubtensorStakingState) -> SubtensorPortfolioGroup? {
        let portfolio = SubtensorPortfolioBuilder.build(state: positionsState)
        let group = isRoot ? portfolio.root : portfolio.subnets.first { $0.netuid == netuid }

        return group.flatMap { $0.totalAlpha > 0 || $0.redeemable > 0 ? $0 : nil }
    }

    func subscribePositions() {
        state.positionsSyncService?.add(
            observer: self,
            onState: { [weak self] newState in
                guard let self, let newState else {
                    return
                }

                presenter?.didReceive(group: findGroup(in: newState))

                if !isRoot, !pricesStore.hasCall {
                    loadPrices()
                }

                if isRoot {
                    presenter?.didReceive(
                        claimable: newState.rootClaimPreviews,
                        isFailed: newState.isRootRedeemableStale
                    )
                }
            },
            onFailure: { [weak self] isFailed in
                self?.presenter?.didReceiveSyncFailure(isFailed)
            }
        )
    }

    func subscribeBlockNumber() {
        do {
            try blockNumberSubscription?.start { [weak self] result in
                switch result {
                case let .success(blockNumber):
                    if let blockNumber {
                        self?.presenter?.didReceive(blockNumber: blockNumber)
                        self?.retryFailedRootHolds()
                    }
                case let .failure(error):
                    self?.logger.warning("Subtensor position block number unavailable: \(error)")
                    self?.dropBlockFeed()
                }
            }
        } catch {
            logger.warning("Subtensor position block number unavailable: \(error)")
            dropBlockFeed()
        }
    }

    func dropBlockFeed() {
        blockNumberSubscription?.unsubscribe()
        isBlockFeedDown = true
    }

    func loadSubnetLogos() {
        load(subnetLogosProvider.createLogosWrapper(), in: logosStore, label: "position subnet mark") { [weak self] in
            self?.presenter?.didReceive(subnetLogos: $0)
        }
    }

    func loadYields() {
        load(
            yieldService.createAlphaYieldsWrapper(for: netuid),
            in: rateStore,
            label: "position yields"
        ) { [weak self] in
            self?.presenter?.didReceive(yields: $0)
        }
    }

    func loadPrices() {
        pricesStore.cancel()

        load(
            alphaPriceProvider.createPricesWrapper(for: [netuid]),
            in: pricesStore,
            label: "position alpha prices"
        ) { [weak self] in
            self?.presenter?.didReceive(prices: $0)
        } fail: { [weak self] in
            self?.presenter?.didFailPrices()
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
    func cachedPrices() -> SubtensorAlphaPrices? {
        guard !isRoot, let prices = alphaPriceProvider.cachedPrices(), prices.taoPerAlpha[netuid] != nil else {
            return nil
        }

        return prices
    }

    func cachedYields() -> SubtensorAlphaYields? {
        yieldService.cachedAlphaYields(for: netuid).value
    }

    func setup() {
        if isRoot {
            subscribeBlockNumber()
        } else {
            loadPrices()
            loadSubnetLogos()
            loadSubnetsInfo()
        }

        subscribePositions()
        subscribeTaoPrice(currency: selectedCurrency)
        loadYields()

        applicationHandler.delegate = self
    }

    func refreshPositions() {
        state.positionsSyncService?.refresh()

        if !isRoot {
            loadPrices()
        }
    }

    func loadSubnetsInfo() {
        subnetsInfoStore.cancel()

        load(
            state.subnetsService.createSubnetsInfoWrapper(),
            in: subnetsInfoStore,
            label: "position subnets"
        ) { [weak self] in
            self?.presenter?.didReceive(subnetsInfo: $0)
        }
    }

    func loadValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef) {
        validatorStore.cancel()

        load(
            validatorFactory.createLockedWrapper(for: hotkey, subnet: subnet),
            in: validatorStore,
            label: "position validator"
        ) { [weak self] in
            self?.presenter?.didReceive(validator: $0, for: hotkey)
        } fail: { [weak self] in
            self?.presenter?.didFailValidator(for: hotkey)
        }
    }

    func loadRootHolds(for hotkeys: [AccountId]) {
        guard let coldkey = state.selectedAccount?.chainAccount.accountId else {
            return
        }

        failedHoldsHotkeys = nil
        holdsStore.cancel()

        guard !hotkeys.isEmpty else {
            presenter?.didReceive(holds: [:], blockTime: nil)
            return
        }

        executeCancellable(
            wrapper: rootHoldFactory.createHoldsWrapper(coldkey: coldkey, hotkeys: hotkeys),
            inOperationQueue: operationQueue,
            backingCallIn: holdsStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success((holds, blockTime)):
                self?.presenter?.didReceive(holds: holds, blockTime: blockTime)
            case let .failure(error):
                self?.logger.warning("Subtensor position root holds unavailable: \(error)")
                self?.failedHoldsHotkeys = hotkeys
            }
        }
    }

    func loadHistory(for subnet: SubtensorSubnetRef, period: SubtensorPricePeriod) {
        historyStore.cancel()

        let wrapper = priceHistoryService?.createHistoryWrapper(
            for: subnet,
            period: period,
            currency: selectedCurrency
        ) ?? .createWithResult(nil)

        executeCancellable(
            wrapper: wrapper,
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

extension SubtensorPositionInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()

        if !isRoot {
            loadPrices()
        } else if isBlockFeedDown {
            isBlockFeedDown = false
            subscribeBlockNumber()
        }

        presenter?.didBecomeActive()
    }
}

extension SubtensorPositionInteractor: SubtensorTaoPriceSubscribing {
    func deliverTaoPrice(_ price: PriceData?) {
        presenter?.didReceive(price: price)
    }
}

extension SubtensorPositionInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        presenter?.didChangeCurrency()
        clear(streamableProvider: &priceProvider)
        subscribeTaoPrice(currency: selectedCurrency)
    }
}
