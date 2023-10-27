import UIKit

final class SwapConfirmInteractor: SwapBaseInteractor {
    weak var presenter: SwapConfirmInteractorOutputProtocol?

    let runtimeService: RuntimeProviderProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let assetConversionExtrinsicService: AssetConversionExtrinsicServiceProtocol
    let payChainAsset: ChainAsset
    let receiveChainAsset: ChainAsset
    let feeChainAsset: ChainAsset
    let slippage: BigRational

    init(
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset,
        feeChainAsset: ChainAsset,
        slippage: BigRational,
        assetConversionFeeService: AssetConversionFeeServiceProtocol,
        assetConversionOperationFactory: AssetConversionOperationFactoryProtocol,
        assetConversionExtrinsicService: AssetConversionExtrinsicServiceProtocol,
        runtimeService: RuntimeProviderProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        selectedAccount: MetaAccountModel,
        operationQueue: OperationQueue
    ) {
        self.runtimeService = runtimeService
        self.extrinsicService = extrinsicService
        self.assetConversionExtrinsicService = assetConversionExtrinsicService
        self.payChainAsset = payChainAsset
        self.receiveChainAsset = receiveChainAsset
        self.feeChainAsset = feeChainAsset
        self.slippage = slippage

        super.init(
            assetConversionOperationFactory: assetConversionOperationFactory,
            assetConversionFeeService: assetConversionFeeService,
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
