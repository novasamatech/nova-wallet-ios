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

    var currentChain: ChainModel?

    private var feeAsset: ChainAsset?

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

    private func provideAssetBalanceExistense(for chainAsset: ChainAsset) {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            let error = ChainRegistryError.runtimeMetadaUnavailable
            basePresenter?.didReceive(baseError: .assetBalanceExistense(error, chainAsset))
            return
        }

        let wrapper = assetStorageFactory.createAssetBalanceExistenceOperation(
            chainId: chainAsset.chain.chainId,
            asset: chainAsset.asset,
            runtimeProvider: runtimeService,
            operationQueue: operationQueue
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(existense):
                self?.basePresenter?.didReceiveAssetBalance(
                    existense: existense,
                    chainAssetId: chainAsset.chainAssetId
                )
            case let .failure(error):
                self?.basePresenter?.didReceive(
                    baseError: .assetBalanceExistense(error, chainAsset)
                )
            }
        }
    }

    func updateChain(with newChain: ChainModel) {
        let oldChainId = currentChain?.chainId
        currentChain = newChain

        if newChain.chainId != oldChainId {
            updateAccountInfoProvider(for: newChain)
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
            case let .failure(error):
                self?.basePresenter?.didReceive(baseError: .quote(error, args))
            }
        }
    }

    func setupReQuoteSubscription(for _: ChainAssetId, assetOut _: ChainAssetId) {
        // by default we always request quote manually
    }

    func fee(route: AssetExchangeRoute, slippage: BigRational) {
        guard let feeAsset else {
            return
        }

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
                    feeChainAssetId: self?.feeAsset?.chainAssetId
                )
            case let .failure(error):
                self?.basePresenter?.didReceive(
                    baseError: .fetchFeeFailed(error, self?.feeAsset?.chainAssetId)
                )
            }
        }
    }

    func chainAccountResponse(for chainAsset: ChainAsset) -> ChainAccountResponse? {
        let metaChainAccountResponse = selectedWallet.fetchMetaChainAccount(for: chainAsset.chain.accountRequest())
        return metaChainAccountResponse?.chainAccount
    }

    func set(receiveChainAsset chainAsset: ChainAsset) {
        updateChain(with: chainAsset.chain)

        provideAssetBalanceExistense(for: chainAsset)

        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)
    }

    func set(payChainAsset chainAsset: ChainAsset) {
        provideAssetBalanceExistense(for: chainAsset)

        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)
    }

    func set(feeChainAsset chainAsset: ChainAsset) {
        guard feeAsset?.chainAssetId != chainAsset.chainAssetId else {
            return
        }

        feeAsset = chainAsset

        provideAssetBalanceExistense(for: chainAsset)

        if let utilityAsset = chainAsset.chain.utilityChainAsset(), !chainAsset.isUtilityAsset {
            provideAssetBalanceExistense(for: utilityAsset)
        }

        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)
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

    func calculateFee(for route: AssetExchangeRoute, slippage: BigRational) {
        fee(route: route, slippage: slippage)
    }

    func retryAssetBalanceSubscription(for chainAsset: ChainAsset) {
        clear(streamableProvider: &assetBalanceProviders[chainAsset.chainAssetId])
        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)
    }

    func remakePriceSubscription(for chainAsset: ChainAsset) {
        clear(streamableProvider: &priceProviders[chainAsset.chainAssetId])
        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
    }

    func retryAssetBalanceExistenseFetch(for chainAsset: ChainAsset) {
        provideAssetBalanceExistense(for: chainAsset)
    }

    func retryAccountInfoSubscription() {
        guard let chain = currentChain else {
            return
        }

        updateAccountInfoProvider(for: chain)
    }

    func requestValidatingQuote(
        for _: AssetConversion.QuoteArgs,
        completion _: @escaping (Result<AssetConversion.Quote, Error>) -> Void
    ) {
        // TODO: Implement
    }
}

extension SwapBaseInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            basePresenter?.didReceive(price: priceData, priceId: priceId)
        case let .failure(error):
            basePresenter?.didReceive(baseError: .price(error, priceId))
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
            basePresenter?.didReceive(baseError: .assetBalance(error, chainAssetId, accountId))
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
            basePresenter?.didReceive(baseError: .accountInfo(error))
        }
    }
}
