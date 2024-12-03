import UIKit
import Operation_iOS
import BigInt

class SwapBaseInteractor: AnyCancellableCleaning, AnyProviderAutoCleaning, SwapBaseInteractorInputProtocol {
    weak var basePresenter: SwapBaseInteractorOutputProtocol?

    let assetsExchangeService: AssetsExchangeServiceProtocol
    let chainRegistry: ChainRegistryProtocol
    let assetStorageFactory: AssetStorageInfoOperationFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let selectedWallet: MetaAccountModel
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var quoteCallStore = CancellableCallStore()
    private var feeCallStore = CancellableCallStore()

    private var priceProviders: [ChainAssetId: StreamableProvider<PriceData>] = [:]
    private var assetBalanceProviders: [ChainAssetId: StreamableProvider<AssetBalance>] = [:]
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?

    init(
        state: SwapTokensFlowStateProtocol,
        chainRegistry: ChainRegistryProtocol,
        assetStorageFactory: AssetStorageInfoOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        selectedWallet: MetaAccountModel,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        assetsExchangeService = state.setupAssetExchangeService()
        self.chainRegistry = chainRegistry
        self.assetStorageFactory = assetStorageFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        generalLocalSubscriptionFactory = state.generalLocalSubscriptionFactory
        self.currencyManager = currencyManager
        self.selectedWallet = selectedWallet
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        quoteCallStore.cancel()
        feeCallStore.cancel()
    }

    private func fetchAssetBalanceExistence(
        for chainAssetIds: Set<ChainAssetId>,
        completion: @escaping (Result<[ChainAssetId: AssetBalanceExistence], Error>) -> Void
    ) {
        do {
            let chainAssetIdList = Array(chainAssetIds)

            let wrappers = try chainAssetIdList.map { chainAssetId in
                let chain = try chainRegistry.getChainOrError(for: chainAssetId.chainId)
                let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chainAssetId.chainId)
                let chainAsset = try chain.chainAssetOrError(for: chainAssetId.assetId)

                return assetStorageFactory.createAssetBalanceExistenceOperation(
                    chainId: chainAsset.chain.chainId,
                    asset: chainAsset.asset,
                    runtimeProvider: runtimeService,
                    operationQueue: operationQueue
                )
            }

            let mappingOperation = ClosureOperation<[ChainAssetId: AssetBalanceExistence]> {
                let balanceExistences = try wrappers.map { try $0.targetOperation.extractNoCancellableResultData() }

                return zip(chainAssetIds, balanceExistences).reduce(
                    into: [ChainAssetId: AssetBalanceExistence]()
                ) {
                    $0[$1.0] = $1.1
                }
            }

            wrappers.forEach { mappingOperation.addDependency($0.targetOperation) }

            let dependencies = wrappers.flatMap(\.allOperations)

            let totalWrapper = CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)

            execute(
                wrapper: totalWrapper,
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { result in
                completion(result)
            }

        } catch {
            completion(.failure(error))
        }
    }

    private func provideAssetBalanceExistenses(for chainAsset: ChainAsset) {
        fetchAssetBalanceExistence(for: [chainAsset.chainAssetId]) { [weak self] result in
            switch result {
            case let .success(existenses):
                guard let existense = existenses[chainAsset.chainAssetId] else {
                    return
                }

                self?.basePresenter?.didReceiveAssetBalance(
                    existense: existense,
                    chainAssetId: chainAsset.chainAssetId
                )
            case let .failure(error):
                self?.basePresenter?.didReceive(
                    baseError: .assetBalanceExistence(error, chainAsset)
                )
            }
        }
    }

    func updateAccountInfoProvider(for chain: ChainModel) {
        clear(dataProvider: &accountInfoProvider)

        guard let accountId = selectedWallet.fetch(for: chain.accountRequest())?.accountId else {
            return
        }

        accountInfoProvider = subscribeAccountInfo(for: accountId, chainId: chain.chainId)
    }

    func updateSubscriptions(activeChainAssets: Set<ChainAssetId>) {
        priceProviders = clear(providers: priceProviders, activeChainAssets: activeChainAssets)
        assetBalanceProviders = clear(providers: assetBalanceProviders, activeChainAssets: activeChainAssets)
    }

    func clear<T>(
        providers: [ChainAssetId: StreamableProvider<T>],
        activeChainAssets: Set<ChainAssetId>
    ) -> [ChainAssetId: StreamableProvider<T>] {
        providers.reduce(into: [ChainAssetId: StreamableProvider<T>]()) {
            if !activeChainAssets.contains($1.key) {
                $1.value.removeObserver(self)
            } else {
                $0[$1.key] = $1.value
            }
        }
    }

    func priceSubscription(chainAsset: ChainAsset) -> StreamableProvider<PriceData>? {
        guard let priceId = chainAsset.asset.priceId else {
            return nil
        }

        return priceProviders[chainAsset.chainAssetId] ?? subscribeToPrice(
            for: priceId,
            currency: currencyManager.selectedCurrency
        )
    }

    func assetBalanceSubscription(chainAsset: ChainAsset) -> StreamableProvider<AssetBalance>? {
        guard let accountId = chainAccountResponse(for: chainAsset)?.accountId else {
            return nil
        }
        let chainAssetId = chainAsset.chainAssetId
        return assetBalanceProviders[chainAssetId] ?? subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId
        )
    }

    func quote(args: AssetConversion.QuoteArgs) {
        quoteCallStore.cancel()

        let wrapper = assetsExchangeService.fetchQuoteWrapper(for: args)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: quoteCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(quote):
                self?.basePresenter?.didReceive(quote: quote, for: args)
                self?.setupReQuoteSubscription(for: args.assetIn, assetOut: args.assetOut)
            case let .failure(error):
                self?.basePresenter?.didReceive(baseError: .quote(error, args))
            }
        }
    }

    func setupReQuoteSubscription(for _: ChainAssetId, assetOut _: ChainAssetId) {
        // by default we always request quote manually
    }

    func fee(route: AssetExchangeRoute, slippage: BigRational, feeAsset: ChainAsset) {
        feeCallStore.cancel()

        let args = AssetExchangeFeeArgs(
            route: route,
            slippage: slippage,
            feeAssetId: feeAsset.chainAssetId
        )

        let wrapper = assetsExchangeService.estimateFee(for: args)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: feeCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(fee):
                self?.basePresenter?.didReceive(
                    fee: fee,
                    feeChainAssetId: fee.feeAssetId
                )
            case let .failure(error):
                self?.basePresenter?.didReceive(
                    baseError: .fetchFeeFailed(error, feeAsset.chainAssetId)
                )
            }
        }
    }

    func chainAccountResponse(for chainAsset: ChainAsset) -> ChainAccountResponse? {
        let metaChainAccountResponse = selectedWallet.fetchMetaChainAccount(for: chainAsset.chain.accountRequest())
        return metaChainAccountResponse?.chainAccount
    }

    func setReceiveChainAssetSubscriptions(_ chainAsset: ChainAsset) {
        provideAssetBalanceExistenses(for: chainAsset)

        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)
    }

    func setPayChainAssetSubscriptions(_ chainAsset: ChainAsset) {
        updateAccountInfoProvider(for: chainAsset.chain)

        provideAssetBalanceExistenses(for: chainAsset)

        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)
    }

    func setFeeChainAssetSubscriptions(_ chainAsset: ChainAsset) {
        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)

        provideAssetBalanceExistenses(for: chainAsset)

        // we still may need utility asset to pay fee on the origin chain
        if
            let utilityChainAsset = chainAsset.chain.utilityChainAsset(),
            utilityChainAsset.chainAssetId != chainAsset.chainAssetId {
            priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: utilityChainAsset)
            assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: utilityChainAsset)

            provideAssetBalanceExistenses(for: chainAsset)
        }
    }

    // MARK: - SwapBaseInteractorInputProtocol

    func setup() {
        assetsExchangeService.subscribeUpdates(
            for: self,
            notifyingIn: .main
        ) {
            // TODO: Update on graph change
        }
    }

    func calculateQuote(for args: AssetConversion.QuoteArgs) {
        quote(args: args)
    }

    func calculateFee(for route: AssetExchangeRoute, slippage: BigRational, feeAsset: ChainAsset) {
        fee(route: route, slippage: slippage, feeAsset: feeAsset)
    }

    func requestValidatingQuote(
        for args: AssetConversion.QuoteArgs,
        completion: @escaping (Result<AssetExchangeQuote, Error>) -> Void
    ) {
        let wrapper = assetsExchangeService.fetchQuoteWrapper(for: args)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main,
            callbackClosure: completion
        )
    }

    func retryAssetBalanceExistenseFetch(for chainAsset: ChainAsset) {
        provideAssetBalanceExistenses(for: chainAsset)
    }
}

extension SwapBaseInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            basePresenter?.didReceive(price: priceData, priceId: priceId)
        case let .failure(error):
            logger.error("Unexpected price error: \(error)")
        }
    }
}

extension SwapBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        let chainAssetId = ChainAssetId(chainId: chainId, assetId: assetId)
        switch result {
        case let .success(balance):
            let balance = balance ?? .createZero(
                for: .init(chainId: chainId, assetId: assetId),
                accountId: accountId
            )

            basePresenter?.didReceive(balance: balance, for: chainAssetId)

        case let .failure(error):
            logger.error("Unexpected balance error: \(error)")
        }
    }
}

extension SwapBaseInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId: ChainModel.Id
    ) {
        switch result {
        case let .success(accountInfo):
            basePresenter?.didReceive(accountInfo: accountInfo, chainId: chainId)
        case let .failure(error):
            logger.error("Unexpected account info error: \(error)")
        }
    }
}
