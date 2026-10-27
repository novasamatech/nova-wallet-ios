import UIKit
import SubstrateSdk
import Operation_iOS

class SubtensorBaseInteractor: RuntimeConstantFetching, AnyProviderAutoCleaning, SubtensorLoadDelivering {
    weak var basePresenter: SubtensorBaseInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: ChainAccountResponse
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol
    let preflightOperationFactory: SubtensorPreflightOperationFactoryProtocol
    let tradeQuoteOperationFactory: SubtensorTradeQuoteOperationFactoryProtocol
    let submissionOperationFactory: SubtensorSubmissionOperationFactoryProtocol
    let catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol
    let costBasisService: SubtensorCostBasisServiceProtocol
    let rootHoldOperationFactory: SubtensorRootHoldOperationFactoryProtocol
    let configProvider: SubtensorConfigProviding
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let blockNumberSubscription: BlockNumberRemoteSubscriptionProtocol?
    let runtimeProvider: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var feeDebouncer = Debouncer(delay: 0.25)
    private var quoteDebouncer = Debouncer(delay: 0.25)
    private var pendingFeeOperation: SubtensorOperation?
    private let shieldQuoteEstimator: SubtensorShieldQuoteEstimator
    private let feeCallStore = CancellableCallStore()
    private let preflightCallStore = CancellableCallStore()
    private let quoteCallStore = CancellableCallStore()
    private let validatingQuoteCallStore = CancellableCallStore()
    private let catalogueCallStore = CancellableCallStore()
    private let logosCallStore = CancellableCallStore()
    private let novaFeeRateCallStore = CancellableCallStore()
    private let costBasisCallStore = CancellableCallStore()
    private let holdsCallStore = CancellableCallStore()
    private var rootHoldsHotkeys: [AccountId] = []

    init(
        flowServices: SubtensorFlowServices,
        state: SubtensorSharedStateProtocol,
        logger: LoggerProtocol
    ) {
        chainAsset = state.stakingOption.chainAsset
        selectedAccount = flowServices.account.chainAccount
        positionsSyncService = flowServices.positionsSyncService
        preflightOperationFactory = flowServices.preflightOperationFactory
        tradeQuoteOperationFactory = flowServices.tradeQuoteOperationFactory
        submissionOperationFactory = flowServices.submissionOperationFactory
        catalogueOperationFactory = state.earnServices.catalogueOperationFactory
        costBasisService = state.earnServices.costBasisService
        rootHoldOperationFactory = state.earnServices.rootHoldOperationFactory
        configProvider = state.earnServices.subnetLogosProvider
        walletLocalSubscriptionFactory = flowServices.walletLocalSubscriptionFactory
        priceLocalSubscriptionFactory = flowServices.priceLocalSubscriptionFactory
        blockNumberSubscription = flowServices.blockNumberSubscription
        runtimeProvider = flowServices.runtimeProvider
        operationQueue = flowServices.operationQueue
        self.logger = logger

        shieldQuoteEstimator = SubtensorShieldQuoteEstimator(
            submissionOperationFactory: flowServices.submissionOperationFactory,
            operationQueue: flowServices.operationQueue,
            logger: logger
        )

        currencyManager = flowServices.currencyManager

        shieldQuoteEstimator.onQuote = { [weak self] quote, operation in
            self?.basePresenter?.didReceiveShieldQuote(quote, for: operation)
        }

        shieldQuoteEstimator.onFallback = { [weak self] operation in
            self?.basePresenter?.didReceiveShieldQuoteFallback(for: operation)
        }
    }

    deinit {
        feeCallStore.cancel()
        preflightCallStore.cancel()
        quoteCallStore.cancel()
        validatingQuoteCallStore.cancel()
        catalogueCallStore.cancel()
        logosCallStore.cancel()
        novaFeeRateCallStore.cancel()
        costBasisCallStore.cancel()
        holdsCallStore.cancel()

        blockNumberSubscription?.unsubscribe()
        positionsSyncService.remove(observer: self)
    }
}

private extension SubtensorBaseInteractor {
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
        do {
            try blockNumberSubscription?.start { [weak self] result in
                switch result {
                case let .success(blockNumber):
                    if let blockNumber {
                        self?.shieldQuoteEstimator.didReceiveBlock(blockNumber)
                        self?.basePresenter?.didReceiveBlockNumber(blockNumber)
                    }
                case let .failure(error):
                    self?.logger.error("Block number subscription failed: \(error)")
                }
            }
        } catch {
            logger.error("Block number subscription failed: \(error)")
        }
    }

    func makePositionsSubscription() {
        positionsSyncService.add(
            observer: self,
            onState: { [weak self] newState in
                self?.basePresenter?.didReceivePositions(newState)
            },
            onFailure: { [weak self] error in
                self?.basePresenter?.didReceivePositionsSyncFailed(error != nil)
            }
        )
    }

    func startPendingEstimates() {
        if let operation = pendingFeeOperation {
            pendingFeeOperation = nil

            executeCancellable(
                wrapper: submissionOperationFactory.createFeeWrapper(for: operation),
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

        shieldQuoteEstimator.startPending()
    }
}

extension SubtensorBaseInteractor: SubtensorBaseInteractorInputProtocol {
    func setup() {
        makeAssetBalanceSubscription()
        makePriceSubscription()
        makeBlockNumberSubscription()
        makePositionsSubscription()
    }

    func estimateFee(for operation: SubtensorOperation) {
        feeCallStore.cancel()
        pendingFeeOperation = operation

        feeDebouncer.debounce { [weak self] in
            self?.startPendingEstimates()
        }
    }

    func estimateShieldQuote(for operation: SubtensorOperation) {
        guard shieldQuoteEstimator.schedule(operation) else {
            return
        }

        feeDebouncer.debounce { [weak self] in
            self?.startPendingEstimates()
        }
    }

    func cancelShieldQuote() {
        shieldQuoteEstimator.cancel()
    }

    func refreshPreflight(for hotkey: AccountId, netuid: UInt16) {
        preflightCallStore.cancel()

        let wrapper = preflightOperationFactory.createPreflightWrapper(
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
        quoteCallStore.cancel()

        quoteDebouncer.debounce { [weak self] in
            guard let self else {
                return
            }

            let wrapper = tradeQuoteOperationFactory.createTradeQuoteWrapper(for: request)

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

    func requestValidatingQuote(
        for request: SubtensorTradeQuoteRequest,
        completion: @escaping (Result<SubtensorTradeQuote, Error>) -> Void
    ) {
        validatingQuoteCallStore.cancel()

        executeCancellable(
            wrapper: tradeQuoteOperationFactory.createTradeQuoteWrapper(for: request),
            inOperationQueue: operationQueue,
            backingCallIn: validatingQuoteCallStore,
            runningCallbackIn: .main,
            callbackClosure: completion
        )
    }

    func refreshPositions() {
        positionsSyncService.refresh()
    }

    func loadExistentialDeposit() {
        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeProvider,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<Balance, Error>) in
            switch result {
            case let .success(deposit):
                self?.basePresenter?.didReceiveExistentialDeposit(deposit)
            case let .failure(error):
                self?.basePresenter?.didReceiveBaseError(.existentialDepositFailed(error))
            }
        }
    }

    func loadCatalogue() {
        catalogueCallStore.cancel()

        let catalogueOperationFactory = catalogueOperationFactory

        load(
            catalogueOperationFactory.createCatalogueWrapper(),
            cached: { catalogueOperationFactory.cachedCatalogue().value },
            in: catalogueCallStore,
            label: "catalogue",
            deliver: { [weak self] in
                self?.basePresenter?.didReceiveCatalogue($0)
            }
        )
    }

    func loadSubnetLogos() {
        logosCallStore.cancel()

        load(configProvider.createLogosWrapper(), in: logosCallStore, label: "subnet logos") { [weak self] in
            self?.basePresenter?.didReceiveSubnetLogos($0)
        }
    }

    func loadNovaFeeRate() {
        novaFeeRateCallStore.cancel()

        load(
            configProvider.createNovaFeeRateWrapper(),
            in: novaFeeRateCallStore,
            label: "nova fee rate"
        ) { [weak self] in
            self?.basePresenter?.didReceiveNovaFeeRate($0)
        }
    }

    func loadCostBasis(for netuid: UInt16) {
        loadCostBasis(
            using: costBasisService,
            accountId: selectedAccount.accountId,
            netuid: netuid,
            in: costBasisCallStore
        ) { [weak self] in
            self?.basePresenter?.didReceiveCostBasis($0)
        }
    }

    func loadRootHolds(for hotkeys: [AccountId]) {
        holdsCallStore.cancel()
        rootHoldsHotkeys = hotkeys

        executeCancellable(
            wrapper: rootHoldOperationFactory.createHoldsWrapper(coldkey: selectedAccount.accountId, hotkeys: hotkeys),
            inOperationQueue: operationQueue,
            backingCallIn: holdsCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success((holds, _)):
                self?.basePresenter?.didReceiveRootHolds(holds)
            case let .failure(error):
                self?.basePresenter?.didReceiveBaseError(.rootHoldsFailed(error))
            }
        }
    }

    func retryRootHolds() {
        loadRootHolds(for: rootHoldsHotkeys)
    }
}

extension SubtensorBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
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

extension SubtensorBaseInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            basePresenter?.didReceivePrice(priceData)
        case let .failure(error):
            logger.error("Price subscription failed: \(error)")
        }
    }
}

extension SubtensorBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil else {
            return
        }

        makePriceSubscription()
    }
}
