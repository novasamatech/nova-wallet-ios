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
    let currencyManager: CurrencyManagerProtocol
    let selectedAccount: MetaAccountModel

    private let operationQueue: OperationQueue
    private var quoteCall: CancellableCall?
    private var runtimeOperationCall: CancellableCall?
    private var extrinsicService: ExtrinsicServiceProtocol?
    private var accountId: AccountId?

    private var priceProviders: [ChainAssetId: StreamableProvider<PriceData>] = [:]

    init(
        assetConversionOperationFactory: AssetConversionOperationFactoryProtocol,
        assetConversionExtrinsicService: AssetConversionExtrinsicServiceProtocol,
        runtimeService: RuntimeProviderProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
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
        self.currencyManager = currencyManager
        self.selectedAccount = selectedAccount
        self.operationQueue = operationQueue
    }

    private func performPriceSubscription(chainAsset: ChainAsset) {
        clear(streamableProvider: &priceProviders[chainAsset.chainAssetId])

        guard let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProviders[chainAsset.chainAssetId] = subscribeToPrice(
            for: priceId,
            currency: currencyManager.selectedCurrency
        )
    }

    private func quote(args: AssetConversion.QuoteArgs) {
        clear(cancellable: &quoteCall)

        let wrapper = assetConversionOperationFactory.quote(for: args)
        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.quoteCall === wrapper else {
                    return
                }
                do {
                    let result = try wrapper.targetOperation.extractNoCancellableResultData()

                    self?.presenter?.didReceive(quote: result)
                } catch {
                    self?.presenter?.didReceive(error: .quote(error))
                }
            }
        }

        quoteCall = wrapper
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func update(chainModel: ChainModel) {
        guard let metaChainAccountResponse = selectedAccount.fetchMetaChainAccount(
            for: chainModel.accountRequest()
        ) else {
            return
        }
        extrinsicService = extrinsicServiceFactory.createService(
            account: metaChainAccountResponse.chainAccount,
            chain: chainModel
        )
        accountId = metaChainAccountResponse.chainAccount.accountId
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
                self.feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: "", setupBy: builder)
            } catch {
                DispatchQueue.main.async {
                    self.presenter?.didReceive(error: .fetchFeeFailed(error))
                }
            }
        }

        runtimeOperationCall = runtimeCoderFactoryOperation
        operationQueue.addOperation(runtimeCoderFactoryOperation)
    }
}

extension SwapSetupInteractor: SwapSetupInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self
    }

    func calculateQuote(for args: AssetConversion.QuoteArgs) {
        quote(args: args)
    }

    func set(chainModel: ChainModel) {
        update(chainModel: chainModel)
    }

    func calculateFee(for args: FeeArgs) {
        guard let receiver = accountId else {
            return
        }
        fee(args: .init(
            assetIn: args.assetIn,
            amountIn: args.amountIn,
            assetOut: args.assetOut,
            amountOut: args.amountOut,
            receiver: receiver,
            direction: args.direction,
            slippage: .percent(of: args.slippage)
        ))
    }

    func performSubscriptions(chainAsset: ChainAsset) {
        // TODO: Add subscription to balance
        performPriceSubscription(chainAsset: chainAsset)
    }
}

extension SwapSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(dispatchInfo):
            let fee = BigUInt(dispatchInfo.fee)
            presenter?.didReceive(fee: fee)
        case let .failure(error):
            presenter?.didReceive(error: .fetchFeeFailed(error))
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
