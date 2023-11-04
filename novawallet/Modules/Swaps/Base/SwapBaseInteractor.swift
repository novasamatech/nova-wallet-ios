import UIKit
import RobinHood
import BigInt

class SwapBaseInteractor: AnyCancellableCleaning, AnyProviderAutoCleaning, SwapBaseInteractorInputProtocol {
    weak var basePresenter: SwapBaseInteractorOutputProtocol?
    let assetConversionAggregator: AssetConversionAggregationFactoryProtocol
    let assetConversionFeeService: AssetConversionFeeServiceProtocol
    let chainRegistry: ChainRegistryProtocol
    let assetStorageFactory: AssetStorageInfoOperationFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let selectedWallet: MetaAccountModel
    let operationQueue: OperationQueue

    private var quoteCall = CancellableCallStore()

    private var priceProviders: [ChainAssetId: StreamableProvider<PriceData>] = [:]
    private var assetBalanceProviders: [ChainAssetId: StreamableProvider<AssetBalance>] = [:]
    private var feeModelBuilder: AssetHubFeeModelBuilder?
    private var currentChain: ChainModel?

    init(
        assetConversionAggregator: AssetConversionAggregationFactoryProtocol,
        assetConversionFeeService: AssetConversionFeeServiceProtocol,
        chainRegistry: ChainRegistryProtocol,
        assetStorageFactory: AssetStorageInfoOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        selectedWallet: MetaAccountModel,
        operationQueue: OperationQueue
    ) {
        self.assetConversionAggregator = assetConversionAggregator
        self.assetConversionFeeService = assetConversionFeeService
        self.chainRegistry = chainRegistry
        self.assetStorageFactory = assetStorageFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.currencyManager = currencyManager
        self.selectedWallet = selectedWallet
        self.operationQueue = operationQueue
    }

    deinit {
        quoteCall.cancel()
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

    func updateFeeModelBuilder(for chain: ChainModel) {
        guard
            let utilityAsset = chain.utilityChainAsset(),
            feeModelBuilder?.utilityChainAssetId != utilityAsset.chainAssetId else {
            return
        }

        feeModelBuilder = AssetHubFeeModelBuilder(
            utilityChainAssetId: utilityAsset.chainAssetId
        ) { [weak self] feeModel, callArgs, feeChainAssetId in
            self?.basePresenter?.didReceive(
                fee: feeModel,
                transactionId: callArgs.identifier,
                feeChainAssetId: feeChainAssetId
            )
        }

        assetBalanceProviders[utilityAsset.chainAssetId] = assetBalanceSubscription(chainAsset: utilityAsset)
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
        quoteCall.cancel()

        guard let chain = currentChain else {
            return
        }

        let wrapper = assetConversionAggregator.createQuoteWrapper(for: chain, args: args)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: quoteCall,
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

    func fee(args: AssetConversion.CallArgs) {
        guard let feeAsset = feeModelBuilder?.feeAsset else {
            return
        }

        assetConversionFeeService.calculate(
            in: feeAsset,
            callArgs: args,
            runCompletionIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(feeModel):
                self?.feeModelBuilder?.apply(feeModel: feeModel, args: args)
            case let .failure(error):
                self?.basePresenter?.didReceive(
                    baseError: .fetchFeeFailed(error, args.identifier, feeAsset.chainAssetId)
                )
            }
        }
    }

    func chainAccountResponse(for chainAsset: ChainAsset) -> ChainAccountResponse? {
        let metaChainAccountResponse = selectedWallet.fetchMetaChainAccount(for: chainAsset.chain.accountRequest())
        return metaChainAccountResponse?.chainAccount
    }

    func set(receiveChainAsset chainAsset: ChainAsset) {
        currentChain = chainAsset.chain

        updateFeeModelBuilder(for: chainAsset.chain)

        provideAssetBalanceExistense(for: chainAsset)

        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)
    }

    func set(payChainAsset chainAsset: ChainAsset) {
        currentChain = chainAsset.chain

        updateFeeModelBuilder(for: chainAsset.chain)

        if let utilityAsset = chainAsset.chain.utilityChainAsset() {
            feeModelBuilder?.apply(feeAsset: utilityAsset)
        }

        provideAssetBalanceExistense(for: chainAsset)

        guard let chainAccount = chainAccountResponse(for: chainAsset) else {
            basePresenter?.didReceive(payAccountId: nil)
            return
        }
        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)

        basePresenter?.didReceive(payAccountId: chainAccount.accountId)
    }

    func set(feeChainAsset chainAsset: ChainAsset) {
        updateFeeModelBuilder(for: chainAsset.chain)
        feeModelBuilder?.apply(feeAsset: chainAsset)

        provideAssetBalanceExistense(for: chainAsset)

        if let utilityAsset = chainAsset.chain.utilityChainAsset(), !chainAsset.isUtilityAsset {
            provideAssetBalanceExistense(for: utilityAsset)
        }

        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)
    }

    // MARK: - SwapBaseInteractorInputProtocol

    func setup() {}

    func calculateQuote(for args: AssetConversion.QuoteArgs) {
        quote(args: args)
    }

    func calculateFee(
        args: AssetConversion.CallArgs
    ) {
        fee(args: args)
    }

    func remakePriceSubscription(for chainAsset: ChainAsset) {
        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
    }

    func retryAssetBalanceExistenseFetch(for chainAsset: ChainAsset) {
        provideAssetBalanceExistense(for: chainAsset)
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

            if feeModelBuilder?.utilityChainAssetId == chainAssetId {
                feeModelBuilder?.apply(recepientUtilityBalance: balance)
            }

            basePresenter?.didReceive(
                balance: balance,
                for: chainAssetId,
                accountId: accountId
            )

        case let .failure(error):
            basePresenter?.didReceive(baseError: .assetBalance(error, chainAssetId, accountId))
        }
    }
}
