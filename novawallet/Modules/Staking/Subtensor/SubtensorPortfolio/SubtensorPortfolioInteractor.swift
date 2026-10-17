import Foundation
import Foundation_iOS
import Operation_iOS

final class SubtensorPortfolioInteractor: AnyProviderAutoCleaning, SubtensorLoadDelivering {
    weak var presenter: SubnetPortfolioInteractorOutputProtocol?

    let state: SubtensorStakingSharedStateProtocol
    let account: MetaChainAccountResponse
    let selectedWalletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let bittensorApiFactory: BittensorApiOperationFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var priceProvider: StreamableProvider<PriceData>?
    private var hasReportedAccountChange = false
    private let catalogueStore = CancellableCallStore()
    private let rootRateStore = CancellableCallStore()
    private let networkRootRateStore = CancellableCallStore()
    private let logosStore = CancellableCallStore()
    private let weeklyChangesStore = CancellableCallStore()
    private let historiesStore = CancellableCallStore()

    private var chainAsset: ChainAsset {
        state.stakingOption.chainAsset
    }

    init(
        state: SubtensorStakingSharedStateProtocol,
        account: MetaChainAccountResponse,
        selectedWalletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        bittensorApiFactory: BittensorApiOperationFactoryProtocol,
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
        catalogueService = state.earnServices.catalogueService
        yieldService = state.earnServices.yieldService
        subnetLogosProvider = state.earnServices.subnetLogosProvider
        priceHistoryService = state.earnServices.priceHistoryService
        self.bittensorApiFactory = bittensorApiFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
    }

    deinit {
        catalogueStore.cancel()
        rootRateStore.cancel()
        networkRootRateStore.cancel()
        logosStore.cancel()
        weeklyChangesStore.cancel()
        historiesStore.cancel()
        state.positionsSyncService?.remove(observer: self)
        state.throttle()
    }
}

extension SubtensorPortfolioInteractor: SubnetPortfolioInteractorInputProtocol {
    func setup() {
        state.setup(for: account)

        provideCatalogue()
        subscribePositions()
        subscribePrice()
        provideSubnetLogos()

        eventCenter.add(observer: self, dispatchIn: .main)
        applicationHandler.delegate = self
    }

    func refresh() {
        provideCatalogue()
        state.positionsSyncService?.refresh()
    }

    func loadHistories(for period: SubtensorPricePeriod) {
        guard
            let priceId = chainAsset.asset.priceId,
            let accountSubject = try? account.chainAccount.accountId.toAddress(using: .defaultSubstrateFormat) else {
            presenter?.didFailHistories(for: period)
            return
        }

        historiesStore.cancel()

        executeCancellable(
            wrapper: createHistoriesWrapper(
                for: period,
                historyPeriod: period.portfolioHistoryPeriod,
                accountSubject: accountSubject,
                taoPriceId: priceId
            ),
            inOperationQueue: operationQueue,
            backingCallIn: historiesStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(histories):
                self?.presenter?.didReceive(histories: histories)
            case let .failure(error):
                self?.logger.warning("Bittensor portfolio chart unavailable: \(error)")
                self?.presenter?.didFailHistories(for: period)
            }
        }
    }

    func loadRootYields() {
        rootRateStore.cancel()

        load(
            yieldService.createAlphaYieldsWrapper(for: SubtensorStakingPallet.rootNetuid),
            in: rootRateStore,
            label: "portfolio root yields"
        ) { [weak self] in
            self?.presenter?.didReceive(rootYields: $0)
        }
    }

    func loadNetworkRootRate() {
        networkRootRateStore.cancel()

        load(
            yieldService.createNetworkRootRateWrapper(),
            in: networkRootRateStore,
            label: "portfolio network root rate"
        ) { [weak self] in
            self?.presenter?.didReceive(networkRootRate: $0??.annualRate)
        }
    }

    func loadWeeklyChanges(for subnets: [SubtensorSubnetRef]) {
        weeklyChangesStore.cancel()

        guard let priceHistoryService, !subnets.isEmpty else {
            presenter?.didReceive(weeklyChanges: [:])
            return
        }

        load(
            priceHistoryService.createWeeklyChangesWrapper(for: subnets),
            in: weeklyChangesStore,
            label: "portfolio weekly changes"
        ) { [weak self] in
            self?.presenter?.didReceive(weeklyChanges: $0 ?? [:])
        }
    }
}

private extension SubtensorPortfolioInteractor {
    func createHistoriesWrapper(
        for period: SubtensorPricePeriod,
        historyPeriod: BittensorApi.PortfolioHistoryPeriod,
        accountSubject: AccountAddress,
        taoPriceId: AssetModel.PriceId
    ) -> CompoundOperationWrapper<SubtensorPortfolioPriceHistories> {
        let currency = selectedCurrency

        let historyWrapper = bittensorApiFactory.createPortfolioHistoryWrapper(
            accountSubject: accountSubject,
            period: historyPeriod
        )

        let taoWrapper = currency.id == Currency.usd.id ? nil : state.flowState.priceSeriesCache.createSeriesWrapper(
            for: taoPriceId,
            currency: currency,
            period: period.sourceCoingeckoPeriod
        )

        let historiesOperation = ClosureOperation<SubtensorPortfolioPriceHistories> {
            SubtensorPortfolioPriceHistories(
                period: period,
                portfolio: try historyWrapper.targetOperation.extractNoCancellableResultData().value,
                taoFiat: try taoWrapper?.targetOperation.extractNoCancellableResultData()
            )
        }

        historiesOperation.addDependency(historyWrapper.targetOperation)
        taoWrapper.map { historiesOperation.addDependency($0.targetOperation) }

        let dependencies = historyWrapper.allOperations + (taoWrapper?.allOperations ?? [])

        return CompoundOperationWrapper(targetOperation: historiesOperation, dependencies: dependencies)
    }

    func subscribePositions() {
        state.positionsSyncService?.add(
            observer: self,
            onState: { [weak self] newState in
                guard let self, let newState else {
                    return
                }

                presenter?.didReceive(state: newState)

                if !catalogueStore.hasCall {
                    provideCatalogue()
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

    func provideCatalogue() {
        catalogueStore.cancel()

        load(
            catalogueService.createCatalogueWrapper(),
            in: catalogueStore,
            label: "portfolio catalogue"
        ) { [weak self] in
            self?.presenter?.didReceive(catalogue: $0)
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

    func processSubtensorStakingChanged(event: SubtensorStakingChanged) {
        guard
            event.chainAssetId == chainAsset.chainAssetId,
            event.accountId == account.chainAccount.accountId else {
            return
        }

        state.positionsSyncService?.refresh()
    }
}

extension SubtensorPortfolioInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
        provideCatalogue()
        state.positionsSyncService?.refresh()
        presenter?.didBecomeActive()
    }
}

extension SubtensorPortfolioInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        guard chainAsset.asset.priceId == priceId else { return }

        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case let .failure(error):
            logger.error("Bittensor portfolio price unavailable: \(error)")
            presenter?.didReceive(price: nil)
        }
    }
}

extension SubtensorPortfolioInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else { return }

        presenter?.didChangeCurrency()
        subscribePrice()
    }
}
