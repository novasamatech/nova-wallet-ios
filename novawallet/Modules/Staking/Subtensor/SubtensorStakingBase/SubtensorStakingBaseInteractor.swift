import UIKit
import SubstrateSdk
import Operation_iOS

class SubtensorStakingBaseInteractor: RuntimeConstantFetching, AnyProviderAutoCleaning {
    weak var basePresenter: SubtensorStakingBaseInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: ChainAccountResponse
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol
    let rootClaimableService: SubtensorRootClaimableServiceProtocol
    let preflightFactory: SubtensorPreflightFactoryProtocol
    let tradeQuoteFactory: SubtensorTradeQuoteFactoryProtocol
    let operationService: SubtensorStakingOperationServiceProtocol
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

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        positionsSyncService: SubtensorPositionsSyncServiceProtocol,
        rootClaimableService: SubtensorRootClaimableServiceProtocol,
        preflightFactory: SubtensorPreflightFactoryProtocol,
        tradeQuoteFactory: SubtensorTradeQuoteFactoryProtocol,
        operationService: SubtensorStakingOperationServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.positionsSyncService = positionsSyncService
        self.rootClaimableService = rootClaimableService
        self.preflightFactory = preflightFactory
        self.tradeQuoteFactory = tradeQuoteFactory
        self.operationService = operationService
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.logger = logger

        self.currencyManager = currencyManager
    }

    deinit {
        feeCallStore.cancel()
        preflightCallStore.cancel()
        quoteCallStore.cancel()

        positionsSyncService.remove(observer: self)
        positionsSyncService.remove(failureObserver: self)
        rootClaimableService.remove(observer: self)
    }

    func onSetup() {}

    func onPositions(_: Multistaking.SubtensorStakingState?) {}
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
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.onPositions(newState)
            self?.basePresenter?.didReceivePositions(newState)
        }
    }

    func makePositionsFailureSubscription() {
        positionsSyncService.add(
            failureObserver: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, isFailed in
            self?.basePresenter?.didReceivePositionsSyncFailed(isFailed)
        }
    }

    func createQuoteWrapper(
        for request: SubtensorTradeQuoteRequest
    ) -> CompoundOperationWrapper<SubtensorTradeQuote> {
        switch request {
        case let .buy(netuid, grossTao, tolerance):
            tradeQuoteFactory.createBuyQuoteWrapper(netuid: netuid, grossTao: grossTao, tolerance: tolerance)
        case let .sell(netuid, alpha, tolerance):
            tradeQuoteFactory.createSellQuoteWrapper(netuid: netuid, alpha: alpha, tolerance: tolerance)
        }
    }

    func makeClaimableSubscription() {
        rootClaimableService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.basePresenter?.didReceiveClaimable(newState)
        }
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
        makePositionsFailureSubscription()
        makeClaimableSubscription()

        provideExistentialDeposit()

        onSetup()
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

            let wrapper = createQuoteWrapper(for: request)

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
