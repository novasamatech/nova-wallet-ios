import UIKit
import Operation_iOS
import BigInt

class SwapBaseInteractor: AnyCancellableCleaning, AnyProviderAutoCleaning, SwapBaseInteractorInputProtocol {
    weak var basePresenter: SwapBaseInteractorOutputProtocol?

    let assetsExchangeService: AssetsExchangeServiceProtocol
    let chainRegistry: ChainRegistryProtocol
    let assetStorageFactory: AssetStorageInfoOperationFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let selectedWallet: MetaAccountModel
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var quoteCallStore = CancellableCallStore()
    private var feeCallStore = CancellableCallStore()

    private var assetBalanceProviders: [ChainAssetId: StreamableProvider<AssetBalance>] = [:]
    private var accountInfoProviders: [ChainModel.Id: AnyDataProvider<DecodedAccountInfo>] = [:]
    private var originAccountInfoChainId: ChainModel.Id?
    private var destinationAccountInfoChainId: ChainModel.Id?

    init(
        state: SwapTokensFlowStateProtocol,
        chainRegistry: ChainRegistryProtocol,
        assetStorageFactory: AssetStorageInfoOperationFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        selectedWallet: MetaAccountModel,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        assetsExchangeService = state.setupAssetExchangeService()
        self.chainRegistry = chainRegistry
        self.assetStorageFactory = assetStorageFactory
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

    func clearAccountInfoProvider(for chainId: ChainModel.Id) {
        accountInfoProviders[chainId]?.removeObserver(self)
        accountInfoProviders[chainId] = nil
    }

    func clearOriginAccountInfoProvider() {
        if let originAccountInfoChainId, originAccountInfoChainId != destinationAccountInfoChainId {
            clearAccountInfoProvider(for: originAccountInfoChainId)
        }

        originAccountInfoChainId = nil
    }

    func updateOriginAccountInfoProvider(for chain: ChainModel) {
        clearOriginAccountInfoProvider()

        guard let accountId = selectedWallet.fetch(for: chain.accountRequest())?.accountId else {
            return
        }

        originAccountInfoChainId = chain.chainId

        if accountInfoProviders[chain.chainId] == nil {
            accountInfoProviders[chain.chainId] = subscribeAccountInfo(for: accountId, chainId: chain.chainId)
        }
    }

    func clearDestinationAccountInfoProvider() {
        if let destinationAccountInfoChainId, destinationAccountInfoChainId != originAccountInfoChainId {
            clearAccountInfoProvider(for: destinationAccountInfoChainId)
        }

        destinationAccountInfoChainId = nil
    }

    func updateDestinationAccountInfoProvider(for chain: ChainModel) {
        clearDestinationAccountInfoProvider()

        guard let accountId = selectedWallet.fetch(for: chain.accountRequest())?.accountId else {
            return
        }

        destinationAccountInfoChainId = chain.chainId

        if accountInfoProviders[chain.chainId] == nil {
            accountInfoProviders[chain.chainId] = subscribeAccountInfo(for: accountId, chainId: chain.chainId)
        }
    }

    func clearSubscriptionsByAssets(_ activeChainAssets: Set<ChainAssetId>) {
        assetBalanceProviders = clear(providers: assetBalanceProviders, activeIds: activeChainAssets)
    }

    func clear<K: Hashable, T>(
        providers: [K: StreamableProvider<T>],
        activeIds: Set<K>
    ) -> [K: StreamableProvider<T>] {
        providers.reduce(into: [K: StreamableProvider<T>]()) {
            if !activeIds.contains($1.key) {
                $1.value.removeObserver(self)
            } else {
                $0[$1.key] = $1.value
            }
        }
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

    func performUpdateOnGraphChange() {
        logger.debug("Asset Exchange graph did change")
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
        updateDestinationAccountInfoProvider(for: chainAsset.chain)

        provideAssetBalanceExistenses(for: chainAsset)

        if let utilityChainAsset = chainAsset.chain.utilityChainAsset() {
            provideAssetBalanceExistenses(for: utilityChainAsset)
        }

        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)
    }

    func setPayChainAssetSubscriptions(_ chainAsset: ChainAsset) {
        updateOriginAccountInfoProvider(for: chainAsset.chain)

        provideAssetBalanceExistenses(for: chainAsset)

        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)
    }

    func setFeeChainAssetSubscriptions(_ chainAsset: ChainAsset) {
        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)

        provideAssetBalanceExistenses(for: chainAsset)

        // we still may need utility asset to pay fee on the origin chain
        if
            let utilityChainAsset = chainAsset.chain.utilityChainAsset(),
            utilityChainAsset.chainAssetId != chainAsset.chainAssetId {
            assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: utilityChainAsset)

            provideAssetBalanceExistenses(for: chainAsset)
        }
    }

    // MARK: - SwapBaseInteractorInputProtocol

    func setup() {
        assetsExchangeService.subscribeUpdates(
            for: self,
            notifyingIn: .main
        ) { [weak self] in
            self?.performUpdateOnGraphChange()
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

    func requestValidatingIntermediateED(
        for operations: [AssetExchangeMetaOperationProtocol],
        completion: @escaping SwapInterEDCheckClosure
    ) {
        guard !operations.isEmpty else {
            completion(nil)
            return
        }

        let assetOutIds = operations.map(\.assetOut.chainAssetId)

        fetchAssetBalanceExistence(for: Set(assetOutIds)) { result in
            switch result {
            case let .success(edMapping):
                for (index, operation) in operations.enumerated() {
                    let minBalance = edMapping[operation.assetOut.chainAssetId]?.minBalance ?? 0

                    if operation.amountOut < minBalance {
                        let checkValue = SwapInterEDNotMet(
                            operationIndex: index,
                            minBalanceResult: .success(minBalance)
                        )

                        completion(checkValue)
                        return
                    }
                }

                completion(nil)
            case let .failure(error):
                let checkValue = SwapInterEDNotMet(
                    operationIndex: 0,
                    minBalanceResult: .failure(error)
                )

                completion(checkValue)
            }
        }
    }

    func retryAssetBalanceExistenseFetch(for chainAsset: ChainAsset) {
        provideAssetBalanceExistenses(for: chainAsset)
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
            logger.debug("Did receive account info for chain \(chainId)")

            basePresenter?.didReceive(accountInfo: accountInfo, chainId: chainId)
        case let .failure(error):
            logger.error("Unexpected account info error: \(error)")
        }
    }
}
