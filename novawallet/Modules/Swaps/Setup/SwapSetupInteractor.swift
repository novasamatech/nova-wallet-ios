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

    private var payAssetPriceProvider: StreamableProvider<PriceData>?
    private var receiveAssetPriceProvider: StreamableProvider<PriceData>?
    private var feeAssetPriceProvider: StreamableProvider<PriceData>?
    private var payAssetBalanceProvider: StreamableProvider<AssetBalance>?
    private var feeAssetBalanceProvider: StreamableProvider<AssetBalance>?

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

    private func priceSubscription(chainAsset: ChainAsset) -> StreamableProvider<PriceData>? {
        guard let priceId = chainAsset.asset.priceId else {
            return nil
        }

        return subscribeToPrice(
            for: priceId,
            currency: currencyManager.selectedCurrency
        )
    }

    private func assetBalanceSubscription(chainAsset: ChainAsset) -> StreamableProvider<AssetBalance>? {
        guard let accountId = chainAccountResponse(for: chainAsset)?.accountId else {
            return nil
        }
        let chainAssetId = chainAsset.chainAssetId
        return subscribeToAssetBalanceProvider(
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

    func chainAccountResponse(for chainAsset: ChainAsset) -> ChainAccountResponse? {
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
        clear(streamableProvider: &receiveAssetPriceProvider)
        if let receiveChainAsset = receiveChainAsset {
            receiveAssetPriceProvider = priceSubscription(chainAsset: receiveChainAsset)
        }
    }

    func update(payChainAsset: ChainAsset?) {
        guard let payChainAsset = payChainAsset else {
            extrinsicService = nil
            presenter?.didReceive(payAccountId: nil)
            return
        }

        if payAssetPriceProvider !== feeAssetPriceProvider {
            clear(streamableProvider: &payAssetPriceProvider)
            payAssetPriceProvider = priceSubscription(chainAsset: payChainAsset)
        }

        if payAssetBalanceProvider !== feeAssetBalanceProvider {
            clear(streamableProvider: &payAssetBalanceProvider)
            payAssetBalanceProvider = assetBalanceSubscription(chainAsset: payChainAsset)
        }

        if let chainAccount = chainAccountResponse(for: payChainAsset) {
            extrinsicService = extrinsicServiceFactory.createService(
                account: chainAccount,
                chain: payChainAsset.chain
            )
            presenter?.didReceive(payAccountId: chainAccount.accountId)
        } else {
            presenter?.didReceive(payAccountId: nil)
        }
    }

    func update(feeChainAsset: ChainAsset?) {
        guard let feeChainAsset = feeChainAsset else {
            return
        }
        if feeAssetPriceProvider !== payAssetPriceProvider {
            clear(streamableProvider: &feeAssetPriceProvider)
            feeAssetPriceProvider = priceSubscription(chainAsset: feeChainAsset)
        }
        if feeAssetBalanceProvider !== payAssetBalanceProvider {
            clear(streamableProvider: &feeAssetBalanceProvider)
            feeAssetBalanceProvider = assetBalanceSubscription(chainAsset: feeChainAsset)
        }
    }

    func calculateFee(
        args: AssetConversion.CallArgs
    ) {
        fee(args: args)
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
