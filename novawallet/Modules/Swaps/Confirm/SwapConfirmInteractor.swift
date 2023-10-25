import UIKit

final class SwapConfirmInteractor: SwapBaseInteractor {
    weak var presenter: SwapConfirmInteractorOutputProtocol?
    let payChainAsset: ChainAsset
    let receiveChainAsset: ChainAsset
    let feeChainAsset: ChainAsset
    let slippage: BigRational

    init(
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset,
        feeChainAsset: ChainAsset,
        slippage: BigRational,
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
        self.payChainAsset = payChainAsset
        self.receiveChainAsset = receiveChainAsset
        self.feeChainAsset = feeChainAsset
        self.slippage = slippage

        super.init(
            assetConversionOperationFactory: assetConversionOperationFactory,
            assetConversionExtrinsicService: assetConversionExtrinsicService,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicServiceFactory: extrinsicServiceFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            currencyManager: currencyManager,
            selectedAccount: selectedAccount,
            operationQueue: operationQueue
        )
    }

    override func setup() {
        super.setup()

        set(payChainAsset: payChainAsset)
        set(receiveChainAsset: receiveChainAsset)
        set(feeChainAsset: feeChainAsset)
    }
}

extension SwapConfirmInteractor: SwapConfirmInteractorInputProtocol {}
