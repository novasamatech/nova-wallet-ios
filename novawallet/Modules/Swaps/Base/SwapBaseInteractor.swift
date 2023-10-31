import UIKit
import RobinHood
import BigInt

class SwapBaseInteractor: AnyCancellableCleaning, AnyProviderAutoCleaning, SwapBaseInteractorInputProtocol {
    weak var basePresenter: SwapBaseInteractorOutputProtocol?
    let assetConversionOperationFactory: AssetConversionOperationFactoryProtocol
    let assetConversionFeeService: AssetConversionFeeServiceProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let selectedWallet: MetaAccountModel

    private let operationQueue: OperationQueue
    private var quoteCall: CancellableCall?

    private var priceProviders: [ChainAssetId: StreamableProvider<PriceData>] = [:]
    private var assetBalanceProviders: [ChainAssetId: StreamableProvider<AssetBalance>] = [:]
    private var feeModelBuilder: AssetHubFeeModelBuilder?

    init(
        assetConversionOperationFactory: AssetConversionOperationFactoryProtocol,
        assetConversionFeeService: AssetConversionFeeServiceProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        selectedWallet: MetaAccountModel,
        operationQueue: OperationQueue
    ) {
        self.assetConversionOperationFactory = assetConversionOperationFactory
        self.assetConversionFeeService = assetConversionFeeService
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.currencyManager = currencyManager
        self.selectedWallet = selectedWallet
        self.operationQueue = operationQueue
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
        clear(cancellable: &quoteCall)

        let wrapper = assetConversionOperationFactory.quote(for: args)
        wrapper.targetOperation.completionBlock = { [weak self, args] in
            DispatchQueue.main.async {
                guard self?.quoteCall === wrapper else {
                    return
                }
                do {
                    let result = try wrapper.targetOperation.extractNoCancellableResultData()

                    self?.basePresenter?.didReceive(quote: result, for: args)
                } catch {
                    self?.basePresenter?.didReceive(baseError: .quote(error, args))
                }
            }
        }

        quoteCall = wrapper
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
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
                self?.basePresenter?.didReceive(baseError: .fetchFeeFailed(error, args.identifier, feeAsset.chainAssetId))
            }
        }
    }

    func chainAccountResponse(for chainAsset: ChainAsset) -> ChainAccountResponse? {
        let metaChainAccountResponse = selectedWallet.fetchMetaChainAccount(for: chainAsset.chain.accountRequest())
        return metaChainAccountResponse?.chainAccount
    }

    func set(receiveChainAsset chainAsset: ChainAsset) {
        updateFeeModelBuilder(for: chainAsset.chain)

        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
    }

    func set(payChainAsset chainAsset: ChainAsset) {
        updateFeeModelBuilder(for: chainAsset.chain)

        if let utilityAsset = chainAsset.chain.utilityChainAsset() {
            feeModelBuilder?.apply(feeAsset: utilityAsset)
        }

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
