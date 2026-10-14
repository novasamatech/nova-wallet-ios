import Foundation
import Foundation_iOS
import Operation_iOS

final class SubtensorPortfolioInteractor: AnyProviderAutoCleaning {
    weak var presenter: SubnetPortfolioInteractorOutputProtocol?

    let state: SubtensorStakingSharedStateProtocol
    let account: MetaChainAccountResponse
    let selectedWalletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let bittensorApiFactory: BittensorApiOperationFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var priceProvider: StreamableProvider<PriceData>?
    private var hasReportedAccountChange = false
    private var heldNetuids: Set<UInt16> = []
    private var forcedCatalogueNetuids: Set<UInt16> = []
    private let catalogueStore = CancellableCallStore()
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
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        subnetLogosProvider: SubtensorSubnetLogosProviderProtocol,
        priceHistoryService: SubtensorPriceHistoryServiceProtocol?,
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
        self.catalogueService = catalogueService
        self.subnetLogosProvider = subnetLogosProvider
        self.priceHistoryService = priceHistoryService
        self.bittensorApiFactory = bittensorApiFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
    }

    deinit {
        catalogueStore.cancel()
        logosStore.cancel()
        weeklyChangesStore.cancel()
        historiesStore.cancel()
        state.positionsSyncService?.remove(observer: self)
        state.positionsSyncService?.remove(failureObserver: self)
        state.positionsSyncService?.remove(fetchObserver: self)
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
            let historyPeriod = period.portfolioHistoryPeriod,
            let accountSubject = try? account.chainAccount.accountId.toAddress(using: .defaultSubstrateFormat) else {
            presenter?.didFailHistories(for: period)
            return
        }

        historiesStore.cancel()

        executeCancellable(
            wrapper: createHistoriesWrapper(
                for: period,
                historyPeriod: historyPeriod,
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

    func loadWeeklyChanges(for subnets: [SubtensorSubnetRef]) {
        weeklyChangesStore.cancel()

        guard let priceHistoryService, !subnets.isEmpty else {
            presenter?.didReceive(weeklyChanges: [:])
            return
        }

        executeCancellable(
            wrapper: priceHistoryService.createWeeklyChangesWrapper(for: subnets),
            inOperationQueue: operationQueue,
            backingCallIn: weeklyChangesStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(changes):
                self?.presenter?.didReceive(weeklyChanges: changes)
            case let .failure(error):
                self?.logger.warning("Bittensor portfolio weekly changes unavailable: \(error)")
                self?.presenter?.didReceive(weeklyChanges: [:])
            }
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
            period: period.sourcePeriod.coingeckoPeriod
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
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            guard let self, let newState else {
                return
            }

            presenter?.didReceive(state: newState)

            heldNetuids = Set(newState.positions.map(\.netuid)).subtracting([SubtensorStakingPallet.rootNetuid])
        }

        state.positionsSyncService?.add(
            fetchObserver: self,
            sendStateOnSubscription: false,
            queue: .main
        ) { [weak self] _, _ in
            guard let self, !catalogueStore.hasCall else {
                return
            }

            provideCatalogue()
        }

        state.positionsSyncService?.add(
            failureObserver: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, isFailed in
            self?.presenter?.didReceiveSyncFailure(isFailed)
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

    func provideCatalogue() {
        catalogueStore.cancel()

        executeCancellable(
            wrapper: catalogueService.createCatalogueWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: catalogueStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(catalogue):
                presenter?.didReceive(catalogue: catalogue)
                refreshCatalogueIfMissing(in: catalogue)
            case let .failure(error):
                logger.warning("Bittensor portfolio catalogue unavailable: \(error)")
                presenter?.didReceive(catalogue: nil)
            }
        }
    }

    func refreshCatalogueIfMissing(in catalogue: SubtensorSubnetCatalogue) {
        let missingNetuids = heldNetuids
            .filter { catalogue.subnet(for: $0) == nil }
            .subtracting(forcedCatalogueNetuids)

        guard !missingNetuids.isEmpty else {
            return
        }

        forcedCatalogueNetuids.formUnion(missingNetuids)
        provideCatalogue()
    }

    func provideSubnetLogos() {
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
                self?.logger.warning("Bittensor portfolio subnet marks unavailable: \(error)")
                self?.presenter?.didReceive(subnetLogos: nil)
            }
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
