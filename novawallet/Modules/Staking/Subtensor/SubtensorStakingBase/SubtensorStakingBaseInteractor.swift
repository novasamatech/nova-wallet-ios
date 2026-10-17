import UIKit
import SubstrateSdk
import Operation_iOS

class SubtensorStakingBaseInteractor: RuntimeConstantFetching, AnyProviderAutoCleaning {
    weak var basePresenter: SubtensorStakingBaseInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: ChainAccountResponse
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol
    let preflightFactory: SubtensorPreflightFactoryProtocol
    let tradeQuoteFactory: SubtensorTradeQuoteFactoryProtocol
    let operationService: SubtensorStakingOperationServiceProtocol
    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let costBasisService: SubtensorCostBasisServiceProtocol
    let rootHoldFactory: SubtensorRootHoldFactoryProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var feeDebouncer = Debouncer(delay: 0.25)
    private var quoteDebouncer = Debouncer(delay: 0.25)
    private let feeCallStore = CancellableCallStore()
    private let preflightCallStore = CancellableCallStore()
    private let quoteCallStore = CancellableCallStore()
    private let catalogueCallStore = CancellableCallStore()
    private let logosCallStore = CancellableCallStore()
    private let costBasisCallStore = CancellableCallStore()
    private let holdsCallStore = CancellableCallStore()

    init(
        flowServices: SubtensorFlowServices,
        state: SubtensorStakingSharedStateProtocol,
        logger: LoggerProtocol
    ) {
        chainAsset = state.stakingOption.chainAsset
        selectedAccount = flowServices.account.chainAccount
        positionsSyncService = flowServices.positionsSyncService
        preflightFactory = flowServices.preflightFactory
        tradeQuoteFactory = flowServices.tradeQuoteFactory
        operationService = flowServices.operationService
        catalogueService = state.earnServices.catalogueService
        costBasisService = state.earnServices.costBasisService
        rootHoldFactory = state.earnServices.rootHoldFactory
        subnetLogosProvider = state.earnServices.subnetLogosProvider
        walletLocalSubscriptionFactory = flowServices.walletLocalSubscriptionFactory
        priceLocalSubscriptionFactory = flowServices.priceLocalSubscriptionFactory
        generalLocalSubscriptionFactory = state.generalLocalSubscriptionFactory
        runtimeProvider = flowServices.runtimeProvider
        operationQueue = flowServices.operationQueue
        self.logger = logger

        currencyManager = flowServices.currencyManager
    }

    deinit {
        feeCallStore.cancel()
        preflightCallStore.cancel()
        quoteCallStore.cancel()
        catalogueCallStore.cancel()
        logosCallStore.cancel()
        costBasisCallStore.cancel()
        holdsCallStore.cancel()

        positionsSyncService.remove(observer: self)
    }
}

private extension SubtensorStakingBaseInteractor {
    func makeAssetBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)

        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func makePriceSubscription() {
        clear(streamableProvider: &priceProvider)

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    func makeBlockNumberSubscription() {
        blockNumberProvider = subscribeToBlockNumber(for: chainAsset.chain.chainId)
    }

    func makePositionsSubscription() {
        positionsSyncService.add(
            observer: self,
            onState: { [weak self] newState in
                self?.basePresenter?.didReceivePositions(newState)
            },
            onFailure: { [weak self] isFailed in
                self?.basePresenter?.didReceivePositionsSyncFailed(isFailed)
            }
        )
    }

    func provideExistentialDeposit() {
        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeProvider,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<Balance, Error>) in
            switch result {
            case let .success(deposit):
                self?.basePresenter?.didReceiveExistentialDeposit(deposit)
            case let .failure(error):
                self?.logger.error("Existential deposit fetch failed: \(error)")
            }
        }
    }
}

extension SubtensorStakingBaseInteractor: SubtensorStakingBaseInteractorInputProtocol {
    func setup() {
        makeAssetBalanceSubscription()
        makePriceSubscription()
        makeBlockNumberSubscription()
        makePositionsSubscription()

        provideExistentialDeposit()
    }

    func cachedCatalogue() -> HTTPCachePeek<SubtensorSubnetCatalogue> {
        catalogueService.cachedCatalogue()
    }

    func cachedCostBasis(netuid: UInt16) -> HTTPCachePeek<SubtensorCostBasis> {
        costBasisService.cachedCostBasis(for: selectedAccount.accountId, netuid: netuid)
    }

    func estimateFee(for operation: SubtensorStakingOperation) {
        feeDebouncer.debounce { [weak self] in
            guard let self else {
                return
            }

            feeCallStore.cancel()

            let wrapper = operationService.createFeeWrapper(for: operation)

            executeCancellable(
                wrapper: wrapper,
                inOperationQueue: operationQueue,
                backingCallIn: feeCallStore,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(fee):
                    self?.basePresenter?.didReceiveFee(fee)
                case let .failure(error):
                    self?.basePresenter?.didReceiveBaseError(.feeFailed(error))
                }
            }
        }
    }

    func refreshPreflight(for hotkey: AccountId, netuid: UInt16) {
        preflightCallStore.cancel()

        let wrapper = preflightFactory.createPreflightWrapper(
            for: selectedAccount.accountId,
            hotkey: hotkey,
            netuid: netuid
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: preflightCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(preflight):
                self?.basePresenter?.didReceivePreflight(preflight)
            case let .failure(error):
                self?.basePresenter?.didReceiveBaseError(.preflightFailed(error))
            }
        }
    }

    func refreshQuote(for request: SubtensorTradeQuoteRequest) {
        quoteDebouncer.debounce { [weak self] in
            guard let self else {
                return
            }

            quoteCallStore.cancel()

            let wrapper = tradeQuoteFactory.createTradeQuoteWrapper(for: request)

            executeCancellable(
                wrapper: wrapper,
                inOperationQueue: operationQueue,
                backingCallIn: quoteCallStore,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(quote):
                    self?.basePresenter?.didReceiveQuote(quote)
                case let .failure(error):
                    self?.basePresenter?.didReceiveBaseError(.quoteFailed(error))
                }
            }
        }
    }

    func refreshPositions() {
        positionsSyncService.refresh()
    }

    func loadCatalogue() {
        catalogueCallStore.cancel()

        executeCancellable(
            wrapper: catalogueService.createCatalogueWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: catalogueCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(catalogue):
                self?.basePresenter?.didReceiveCatalogue(catalogue)
            case let .failure(error):
                self?.logger.warning("Subtensor catalogue unavailable: \(error)")
                self?.basePresenter?.didReceiveCatalogue(nil)
            }
        }
    }

    func loadSubnetLogos() {
        logosCallStore.cancel()

        executeCancellable(
            wrapper: subnetLogosProvider.createLogosWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: logosCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(logos):
                self?.basePresenter?.didReceiveSubnetLogos(logos)
            case let .failure(error):
                self?.logger.warning("Subtensor subnet logos unavailable: \(error)")
                self?.basePresenter?.didReceiveSubnetLogos(nil)
            }
        }
    }

    func loadCostBasis(for netuid: UInt16) {
        costBasisCallStore.cancel()

        executeCancellable(
            wrapper: costBasisService.createCostBasisWrapper(for: selectedAccount.accountId, netuid: netuid),
            inOperationQueue: operationQueue,
            backingCallIn: costBasisCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(costBasis):
                self?.basePresenter?.didReceiveCostBasis(costBasis)
            case let .failure(error):
                self?.logger.warning("Subtensor cost basis unavailable on netuid \(netuid): \(error)")
                self?.basePresenter?.didReceiveCostBasis(nil)
            }
        }
    }

    func loadRootHolds(for hotkeys: [AccountId]) {
        holdsCallStore.cancel()

        executeCancellable(
            wrapper: rootHoldFactory.createHoldsWrapper(coldkey: selectedAccount.accountId, hotkeys: hotkeys),
            inOperationQueue: operationQueue,
            backingCallIn: holdsCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success((holds, _)):
                self?.basePresenter?.didReceiveRootHolds(holds)
            case let .failure(error):
                self?.logger.warning("Subtensor root holds unavailable: \(error)")
            }
        }
    }
}

extension SubtensorStakingBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            basePresenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            logger.error("Balance subscription failed: \(error)")
        }
    }
}

extension SubtensorStakingBaseInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            basePresenter?.didReceivePrice(priceData)
        case let .failure(error):
            logger.error("Price subscription failed: \(error)")
        }
    }
}

extension SubtensorStakingBaseInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber {
                basePresenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            logger.error("Block number subscription failed: \(error)")
        }
    }
}

extension SubtensorStakingBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil else {
            return
        }

        makePriceSubscription()
    }
}
