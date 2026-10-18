import Foundation
import Foundation_iOS
import Operation_iOS

final class SubtensorPositionInteractor: AnyProviderAutoCleaning, SubtensorLoadDelivering {
    weak var presenter: SubtensorPositionInteractorOutputProtocol?

    let state: SubtensorSharedStateProtocol
    let netuid: UInt16
    let alphaPriceOperationFactory: SubtensorAlphaPriceOperationFactoryProtocol
    let yieldOperationFactory: SubtensorYieldOperationFactoryProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let priceHistoryOperationFactory: SubtensorPriceHistoryOperationFactoryProtocol?
    let directoryOperationFactory: SubtensorValidatorDirectoryOperationFactoryProtocol
    let rootHoldOperationFactory: SubtensorRootHoldOperationFactoryProtocol
    let blockNumberSubscription: BlockNumberRemoteSubscriptionProtocol?
    let applicationHandler: ApplicationHandlerProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    var priceProvider: StreamableProvider<PriceData>?
    private var failedHoldsHotkeys: [AccountId]?
    private var isBlockFeedDown = false
    private var lastGroup: SubtensorPortfolioGroup?
    private var claimable: [SubtensorRootClaimPreview]?
    private let pricesStore = CancellableCallStore()
    private let logosStore = CancellableCallStore()
    private let validatorStore = CancellableCallStore()
    private let rateStore = CancellableCallStore()
    private let holdsStore = CancellableCallStore()
    private let historyStore = CancellableCallStore()
    private let subnetsInfoStore = CancellableCallStore()

    private var isRoot: Bool {
        netuid == SubtensorPallet.rootNetuid
    }

    var chainAsset: ChainAsset {
        state.stakingOption.chainAsset
    }

    init(
        state: SubtensorSharedStateProtocol,
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
        alphaPriceOperationFactory = state.earnServices.alphaPriceOperationFactory
        yieldOperationFactory = state.earnServices.yieldOperationFactory
        subnetLogosProvider = state.earnServices.subnetLogosProvider
        priceHistoryOperationFactory = state.earnServices.priceHistoryOperationFactory
        directoryOperationFactory = state.earnServices.validatorDirectoryOperationFactory
        rootHoldOperationFactory = state.earnServices.rootHoldOperationFactory
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
    func findGroup(in positionsState: Multistaking.SubtensorState) -> SubtensorPortfolioGroup? {
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

                let group = findGroup(in: newState)

                presenter?.didReceive(group: group)

                if !isRoot, group != lastGroup, !pricesStore.hasCall {
                    loadPrices()
                }

                lastGroup = group

                if isRoot {
                    claimable = newState.rootClaimPreviews
                    providePendingClaims()

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
                    self?.isBlockFeedDown = false

                    if let blockNumber {
                        self?.providePendingClaims()
                        self?.presenter?.didReceive(blockNumber: blockNumber)
                        self?.retryFailedRootHolds()
                    }
                case let .failure(error):
                    self?.logger.warning("Subtensor position block number unavailable: \(error)")
                    self?.isBlockFeedDown = true
                }
            }
        } catch {
            logger.warning("Subtensor position block number unavailable: \(error)")
            isBlockFeedDown = true
        }
    }

    func rearmBlockFeed() {
        isBlockFeedDown = false
        blockNumberSubscription?.unsubscribe()
        subscribeBlockNumber()
    }

    func loadSubnetLogos() {
        load(subnetLogosProvider.createLogosWrapper(), in: logosStore, label: "position subnet mark") { [weak self] in
            self?.presenter?.didReceive(subnetLogos: $0)
        }
    }

    func loadYields() {
        let yieldOperationFactory = yieldOperationFactory
        let netuid = netuid

        load(
            yieldOperationFactory.createAlphaYieldsWrapper(for: netuid),
            cached: { yieldOperationFactory.cachedFreshAlphaYields(for: netuid) },
            in: rateStore,
            label: "position yields",
            deliver: { [weak self] in
                self?.presenter?.didReceive(yields: $0)
            }
        )
    }

    func providePendingClaims() {
        guard isRoot, let coldkey = state.selectedAccount?.chainAccount.accountId else {
            return
        }

        let hotkeys = state.flowState.pendingRootClaims.pendingHotkeys(
            for: coldkey,
            at: Date(),
            claimable: claimable
        )

        presenter?.didReceive(pendingClaimHotkeys: hotkeys)
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

    func refreshPendingClaims() {
        providePendingClaims()
    }

    func refreshPositions() {
        state.positionsSyncService?.refresh()

        if !isRoot {
            loadPrices()
        }
    }

    func loadPrices() {
        pricesStore.cancel()

        let alphaPriceOperationFactory = alphaPriceOperationFactory
        let netuid = netuid

        load(
            alphaPriceOperationFactory.createPricesWrapper(for: [netuid]),
            cached: { alphaPriceOperationFactory.cachedPrices().flatMap { $0.taoPerAlpha[netuid] != nil ? $0 : nil } },
            in: pricesStore,
            label: "position alpha prices",
            deliver: { [weak self] prices in
                if let prices {
                    self?.presenter?.didReceive(prices: prices)
                } else {
                    self?.presenter?.didFailPrices()
                }
            }
        )
    }

    func loadSubnetsInfo() {
        subnetsInfoStore.cancel()

        load(
            state.subnetsOperationFactory.createSubnetInfoWrapper(for: netuid),
            in: subnetsInfoStore,
            label: "position subnets"
        ) { [weak self] in
            self?.presenter?.didReceive(subnetsInfo: $0)
        }
    }

    func loadValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef) {
        validatorStore.cancel()

        load(
            directoryOperationFactory.createListedDetailWrapper(for: hotkey, subnet: subnet),
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
            wrapper: rootHoldOperationFactory.createHoldsWrapper(coldkey: coldkey, hotkeys: hotkeys),
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

        let wrapper = priceHistoryOperationFactory?.createHistoryWrapper(
            for: subnet,
            period: period,
            currency: selectedCurrency
        ) ?? .createWithResult(nil)

        load(wrapper, in: historyStore, label: "position price history") { [weak self] in
            self?.presenter?.didReceive(history: $0, for: period)
        } fail: { [weak self] in
            self?.presenter?.didFailHistory(for: period)
        }
    }
}

extension SubtensorPositionInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
        providePendingClaims()

        if !isRoot {
            loadPrices()
        } else if isBlockFeedDown {
            rearmBlockFeed()
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
