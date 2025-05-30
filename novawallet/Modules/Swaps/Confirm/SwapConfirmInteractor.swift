import UIKit
import Operation_iOS
import NovaCrypto
import BigInt

final class SwapConfirmInteractor: SwapBaseInteractor {
    let initState: SwapConfirmInitState

    init(
        state: SwapTokensFlowStateProtocol,
        initState: SwapConfirmInitState,
        chainRegistry: ChainRegistryProtocol,
        assetStorageFactory: AssetStorageInfoOperationFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        selectedWallet: MetaAccountModel,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.initState = initState

        super.init(
            state: state,
            chainRegistry: chainRegistry,
            assetStorageFactory: assetStorageFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            currencyManager: currencyManager,
            selectedWallet: selectedWallet,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    override func setup() {
        super.setup()

        setPayChainAssetSubscriptions(initState.chainAssetIn)
        setReceiveChainAssetSubscriptions(initState.chainAssetOut)
        setFeeChainAssetSubscriptions(initState.feeChainAsset)
    }
}

extension SwapConfirmInteractor: SwapConfirmInteractorInputProtocol {}
