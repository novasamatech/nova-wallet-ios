import Foundation
import Operation_iOS

final class SubtensorPositionInteractor: AnyProviderAutoCleaning, SubtensorLoadDelivering {
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
    private let subnetsInfoStore = CancellableCallStore()

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
        [catalogueStore, logosStore, validatorStore, rateStore, holdsStore, historyStore, subnetsInfoStore].forEach {
            $0.cancel()
        }

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

    func subscribePrice() {
        clear(streamableProvider: &priceProvider)

        guard let priceId = chainAsset.asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
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

    func loadCatalogue() {
        catalogueStore.cancel()

        load(
            catalogueService.createCatalogueWrapper(),
            in: catalogueStore,
            label: "position catalogue"
        ) { [weak self] in
            self?.presenter?.didReceive(catalogue: $0)
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
    func cachedCatalogue() -> SubtensorSubnetCatalogue? {
        guard !isRoot, let catalogue = catalogueService.cachedCatalogue().value else {
            return nil
        }

        return catalogue.subnet(for: netuid) != nil ? catalogue : nil
    }

    func cachedYields() -> SubtensorAlphaYields? {
        yieldService.cachedAlphaYields(for: netuid).value
    }

    func setup() {
        subscribePositions()
        subscribePrice()
        loadYields()

        if isRoot {
            blockNumberProvider = subscribeToBlockNumber(for: chainAsset.chain.chainId)
        } else {
            loadCatalogue()
            loadSubnetLogos()
            loadSubnetsInfo()
        }
    }

    func refreshPositions() {
        state.positionsSyncService?.refresh()
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
            self?.presenter?.didReceive(validator: $0 ?? nil, for: hotkey)
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
