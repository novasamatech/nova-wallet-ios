import Foundation
import Foundation_iOS
import Operation_iOS

final class SubtensorPortfolioInteractor: AnyProviderAutoCleaning, SubtensorLoadDelivering {
    weak var presenter: SubtensorPortfolioInteractorOutputProtocol?

    let state: SubtensorSharedStateProtocol
    let account: MetaChainAccountResponse
    let selectedWalletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let alphaPriceOperationFactory: SubtensorAlphaPriceOperationFactoryProtocol
    let yieldOperationFactory: SubtensorYieldOperationFactoryProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let priceHistoryOperationFactory: SubtensorPriceHistoryOperationFactoryProtocol?
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    var priceProvider: StreamableProvider<PriceData>?
    private var hasReportedAccountChange = false
    private var requestedNetuids: Set<UInt16> = []
    private let pricesStore = CancellableCallStore()
    private let rootRateStore = CancellableCallStore()
    private let networkRootRateStore = CancellableCallStore()
    private let logosStore = CancellableCallStore()
    private let weeklyChangesStore = CancellableCallStore()
    private let historiesStore = CancellableCallStore()

    var chainAsset: ChainAsset {
        state.stakingOption.chainAsset
    }

    private var accountSubject: AccountAddress? {
        try? account.chainAccount.accountId.toAddress(using: .defaultSubstrateFormat)
    }

    init(
        state: SubtensorSharedStateProtocol,
        account: MetaChainAccountResponse,
        selectedWalletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.state = state
        self.account = account
        self.selectedWalletSettings = selectedWalletSettings
        self.eventCenter = eventCenter
        self.applicationHandler = applicationHandler
        alphaPriceOperationFactory = state.earnServices.alphaPriceOperationFactory
        yieldOperationFactory = state.earnServices.yieldOperationFactory
        subnetLogosProvider = state.earnServices.subnetLogosProvider
        priceHistoryOperationFactory = state.earnServices.priceHistoryOperationFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
    }

    deinit {
        pricesStore.cancel()
        rootRateStore.cancel()
        networkRootRateStore.cancel()
        logosStore.cancel()
        weeklyChangesStore.cancel()
        historiesStore.cancel()
        state.positionsSyncService?.remove(observer: self)
        state.positionsSyncService?.unsubscribeSyncState(self)
        state.throttle()
    }
}

extension SubtensorPortfolioInteractor: SubtensorPortfolioInteractorInputProtocol {
    func setup() {
        state.setup(for: account)

        subscribePositions()
        subscribeTaoPrice(currency: selectedCurrency)
        provideSubnetLogos()

        eventCenter.add(observer: self, dispatchIn: .main)
        applicationHandler.delegate = self
    }

    func refresh() {
        providePrices(for: requestedNetuids)
        state.positionsSyncService?.refresh()
    }

    func refreshAll() {
        priceProvider?.refresh()
        provideSubnetLogos()
        refresh()

        if state.positionsSyncService == nil {
            presenter?.didReceivePositionsSyncing(false)
        }
    }

    func loadHistories(for period: SubtensorPricePeriod) {
        guard let priceHistoryOperationFactory, let accountSubject else {
            presenter?.didFailHistories(for: period)
            return
        }

        historiesStore.cancel()

        let wrapper = priceHistoryOperationFactory.createPortfolioHistoryWrapper(
            accountSubject: accountSubject,
            period: period,
            currency: selectedCurrency
        )

        load(wrapper, in: historiesStore, label: "portfolio chart") { [weak self] in
            self?.presenter?.didReceive(histories: $0)
        } fail: { [weak self] in
            self?.presenter?.didFailHistories(for: period)
        }
    }

    func loadRootYields() {
        rootRateStore.cancel()

        load(
            yieldOperationFactory.createAlphaYieldsWrapper(for: SubtensorPallet.rootNetuid),
            in: rootRateStore,
            label: "portfolio root yields"
        ) { [weak self] in
            self?.presenter?.didReceive(rootYields: $0)
        }
    }

    func loadNetworkRootRate() {
        networkRootRateStore.cancel()

        load(
            yieldOperationFactory.createNetworkRootRateWrapper(),
            in: networkRootRateStore,
            label: "portfolio network root rate"
        ) { [weak self] in
            self?.presenter?.didReceive(networkRootRate: $0??.annualRate)
        }
    }

    func loadWeeklyChanges(for subnets: [SubtensorSubnetRef]) {
        weeklyChangesStore.cancel()

        guard let priceHistoryOperationFactory, !subnets.isEmpty else {
            presenter?.didReceive(weeklyChanges: [:])
            return
        }

        load(
            priceHistoryOperationFactory.createWeeklyChangesWrapper(for: subnets),
            in: weeklyChangesStore,
            label: "portfolio weekly changes"
        ) { [weak self] in
            self?.presenter?.didReceive(weeklyChanges: $0)
        } fail: { [weak self] in
            self?.presenter?.didFailWeeklyChanges()
        }
    }
}

private extension SubtensorPortfolioInteractor {
    func subscribePositions() {
        state.positionsSyncService?.add(
            observer: self,
            onState: { [weak self] newState in
                guard let self, let newState else {
                    return
                }

                presenter?.didReceive(state: newState)

                if !pricesStore.hasCall || newState.heldSubnetNetuids != requestedNetuids {
                    providePrices(for: newState.heldSubnetNetuids)
                }
            },
            onFailure: { [weak self] isFailed in
                self?.presenter?.didReceiveSyncFailure(isFailed)
            }
        )

        state.positionsSyncService?.subscribeSyncState(self, queue: .main) { [weak self] _, isSyncing in
            self?.presenter?.didReceivePositionsSyncing(isSyncing)
        }
    }

    func providePrices(for netuids: Set<UInt16>) {
        requestedNetuids = netuids
        pricesStore.cancel()

        load(
            alphaPriceOperationFactory.createPricesWrapper(for: netuids),
            in: pricesStore,
            label: "portfolio alpha prices"
        ) { [weak self] in
            self?.presenter?.didReceive(prices: $0)
        }
    }

    func provideSubnetLogos() {
        load(subnetLogosProvider.createLogosWrapper(), in: logosStore, label: "portfolio subnet marks") { [weak self] in
            self?.presenter?.didReceive(subnetLogos: $0)
        }
    }

    func verifyBoundAccount() {
        guard !hasReportedAccountChange, !isBoundAccountSelected() else { return }

        hasReportedAccountChange = true
        presenter?.didReceiveAccountChange()
    }

    func isBoundAccountSelected() -> Bool {
        guard
            let boundAccount = state.selectedAccount,
            let selectedAccount = selectedWalletSettings.value?.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ) else {
            return false
        }

        return selectedAccount.metaId == boundAccount.metaId &&
            selectedAccount.chainAccount.accountId == boundAccount.chainAccount.accountId
    }
}

extension SubtensorPortfolioInteractor: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        verifyBoundAccount()
    }

    func processWalletRemoved(event _: WalletRemoved) {
        verifyBoundAccount()
    }

    func processChainAccountChanged(event _: ChainAccountChanged) {
        verifyBoundAccount()
    }

    func processSubtensorStakeChanged(event: SubtensorStakeChanged) {
        guard
            event.accountId == account.chainAccount.accountId,
            event.chainAssetId == chainAsset.chainAssetId,
            let accountSubject else {
            return
        }

        priceHistoryOperationFactory?.dropPortfolioHistory(accountSubject: accountSubject)
        presenter?.didChangeStake()
    }
}

extension SubtensorPortfolioInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
        providePrices(for: requestedNetuids)
        state.positionsSyncService?.refresh()
        presenter?.didBecomeActive()
    }
}

extension SubtensorPortfolioInteractor: SubtensorTaoPriceSubscribing {
    func deliverTaoPrice(_ price: PriceData?) {
        presenter?.didReceive(price: price)
    }
}

extension SubtensorPortfolioInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else { return }

        presenter?.didChangeCurrency()
        clear(streamableProvider: &priceProvider)
        subscribeTaoPrice(currency: selectedCurrency)
    }
}
