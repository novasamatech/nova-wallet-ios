import UIKit
import RobinHood
import BigInt

final class SwapSetupInteractor: AnyCancellableCleaning, AnyProviderAutoCleaning {
    weak var presenter: SwapSetupInteractorOutputProtocol?
    let assetConversionOperationFactory: AssetConversionOperationFactoryProtocol
    let assetConversionExtrinsicService: AssetConversionExtrinsicServiceProtocol
    let runtimeService: RuntimeProviderProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let selectedAccount: MetaAccountModel

    private let operationQueue: OperationQueue
    private var quoteCall: CancellableCall?
    private var runtimeOperationCall: CancellableCall?
    private var extrinsicService: ExtrinsicServiceProtocol?

    private var priceProviders: [ChainAssetId: StreamableProvider<PriceData>] = [:]
    private var assetBalanceProviders: [ChainAssetId: StreamableProvider<AssetBalance>] = [:]

    private var receiveChainAsset: ChainAsset? {
        didSet {
            updateSubscriptions()
        }
    }

    private var payChainAsset: ChainAsset? {
        didSet {
            updateSubscriptions()
        }
    }

    private var feeChainAsset: ChainAsset? {
        didSet {
            updateSubscriptions()
        }
    }

    private var activeChainAssets: Set<ChainAssetId> {
        Set(
            [
                receiveChainAsset?.chainAssetId,
                payChainAsset?.chainAssetId,
                feeChainAsset?.chainAssetId
            ].compactMap { $0 }
        )
    }

    init(
        assetConversionOperationFactory: AssetConversionOperationFactoryProtocol,
        assetConversionExtrinsicService: AssetConversionExtrinsicServiceProtocol,
        runtimeService: RuntimeProviderProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        selectedAccount: MetaAccountModel,
        operationQueue: OperationQueue
    ) {
        self.assetConversionOperationFactory = assetConversionOperationFactory
        self.assetConversionExtrinsicService = assetConversionExtrinsicService
        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.currencyManager = currencyManager
        self.selectedAccount = selectedAccount
        self.operationQueue = operationQueue
    }

    private func updateExtrinsicService() {
        guard let chainAsset = feeChainAsset, let chainAccount = chainAccountResponse(for: chainAsset) else {
            extrinsicService = nil
            return
        }

        guard !chainAsset.isUtilityAsset else {
            extrinsicService = extrinsicServiceFactory.createService(
                account: chainAccount,
                chain: chainAsset.chain
            )
            return
        }

        if
            let assetType = chainAsset.asset.type,
            case .statemine = AssetType(rawValue: assetType),
            let typeExtras = chainAsset.asset.typeExtras,
            let extras = try? typeExtras.map(to: StatemineAssetExtras.self),
            let assetId = UInt32(extras.assetId) {
            extrinsicService = extrinsicServiceFactory.createService(
                account: chainAccount,
                chain: chainAsset.chain,
                feeAssetId: assetId
            )
        } else {
            extrinsicService = nil
        }
    }

    private func updateSubscriptions() {
        priceProviders = clear(providers: priceProviders)
        assetBalanceProviders = clear(providers: assetBalanceProviders)
    }

    private func clear<T>(providers: [ChainAssetId: StreamableProvider<T>]) -> [ChainAssetId: StreamableProvider<T>] {
        providers.reduce(into: [ChainAssetId: StreamableProvider<T>]()) {
            if !activeChainAssets.contains($1.key) {
                $1.value.removeObserver(self)
            } else {
                $0[$1.key] = $1.value
            }
        }
    }

    private func priceSubscription(chainAsset: ChainAsset) -> StreamableProvider<PriceData>? {
        guard let priceId = chainAsset.asset.priceId else {
            return nil
        }

        return priceProviders[chainAsset.chainAssetId] ?? subscribeToPrice(
            for: priceId,
            currency: currencyManager.selectedCurrency
        )
    }

    private func assetBalanceSubscription(chainAsset: ChainAsset) -> StreamableProvider<AssetBalance>? {
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

    private func quote(args: AssetConversion.QuoteArgs) {
        clear(cancellable: &quoteCall)

        let wrapper = assetConversionOperationFactory.quote(for: args)
        wrapper.targetOperation.completionBlock = { [weak self, args] in
            DispatchQueue.main.async {
                guard self?.quoteCall === wrapper else {
                    return
                }
                do {
                    let result = try wrapper.targetOperation.extractNoCancellableResultData()

                    self?.presenter?.didReceive(quote: result, for: args)
                } catch {
                    self?.presenter?.didReceive(error: .quote(error, args))
                }
            }
        }

        quoteCall = wrapper
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func fee(args: AssetConversion.CallArgs) {
        clear(cancellable: &runtimeOperationCall)
        guard let extrinsicService = extrinsicService else {
            return
        }

        let runtimeCoderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        runtimeCoderFactoryOperation.completionBlock = { [weak self] in
            guard let self = self else {
                return
            }
            do {
                let runtimeCoderFactory = try runtimeCoderFactoryOperation.extractNoCancellableResultData()
                let builder = self.assetConversionExtrinsicService.fetchExtrinsicBuilderClosure(
                    for: args,
                    codingFactory: runtimeCoderFactory
                )
                self.feeProxy.estimateFee(
                    using: extrinsicService,
                    reuseIdentifier: args.identifier,
                    setupBy: builder
                )
            } catch {
                DispatchQueue.main.async {
                    self.presenter?.didReceive(error: .fetchFeeFailed(error, args.identifier))
                }
            }
        }

        runtimeOperationCall = runtimeCoderFactoryOperation
        operationQueue.addOperation(runtimeCoderFactoryOperation)
    }

    private func chainAccountResponse(for chainAsset: ChainAsset) -> ChainAccountResponse? {
        let metaChainAccountResponse = selectedAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest())
        return metaChainAccountResponse?.chainAccount
    }
}

extension SwapSetupInteractor: SwapSetupInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self
    }

    func calculateQuote(for args: AssetConversion.QuoteArgs) {
        quote(args: args)
    }

    func update(receiveChainAsset: ChainAsset?) {
        self.receiveChainAsset = receiveChainAsset

        if let chainAsset = receiveChainAsset {
            priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
        }
    }

    func update(payChainAsset: ChainAsset?) {
        self.payChainAsset = payChainAsset

        guard let chainAsset = payChainAsset,
              let chainAccount = chainAccountResponse(for: chainAsset) else {
            presenter?.didReceive(payAccountId: nil)
            return
        }
        
        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)

        presenter?.didReceive(payAccountId: chainAccount.accountId)
    }

    func update(feeChainAsset: ChainAsset?) {
        self.feeChainAsset = feeChainAsset

        updateExtrinsicService()

        guard let chainAsset = feeChainAsset else {
            return
        }

        priceProviders[chainAsset.chainAssetId] = priceSubscription(chainAsset: chainAsset)
        assetBalanceProviders[chainAsset.chainAssetId] = assetBalanceSubscription(chainAsset: chainAsset)
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

extension SwapSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for transactionId: TransactionFeeId) {
        DispatchQueue.main.async {
            switch result {
            case let .success(dispatchInfo):
                let fee = BigUInt(dispatchInfo.fee)
                self.presenter?.didReceive(fee: fee, transactionId: transactionId)
            case let .failure(error):
                self.presenter?.didReceive(error: .fetchFeeFailed(error, transactionId))
            }
        }
    }
}

extension SwapSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData, priceId: priceId)
        case let .failure(error):
            presenter?.didReceive(error: .price(error, priceId))
        }
    }
}

extension SwapSetupInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
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
            presenter?.didReceive(
                balance: balance,
                for: chainAssetId,
                accountId: accountId
            )
        case let .failure(error):
            presenter?.didReceive(error: .assetBalance(error, chainAssetId, accountId))
        }
    }
}
