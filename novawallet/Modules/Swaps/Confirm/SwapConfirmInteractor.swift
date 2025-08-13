import UIKit
import Operation_iOS
import NovaCrypto
import BigInt

final class SwapConfirmInteractor: SwapBaseInteractor {
    let initState: SwapConfirmInitState
    let delayedExecutionProvider: WalletDelayedExecutionProviding

    var presenter: SwapConfirmInteractorOutProtocol? {
        get {
            basePresenter as? SwapConfirmInteractorOutProtocol
        }

        set {
            basePresenter = newValue
        }
    }

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
        delayedExecutionProvider = state.setupWalletDelayedCallExecProvider()

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

extension SwapConfirmInteractor: SwapConfirmInteractorInputProtocol {
    func initiateSwapSubmission(of model: SwapExecutionModel) {
        guard delayedExecutionProvider.getCurrentState().executesCallWithDelay(
            selectedWallet,
            chain: model.chainAssetIn.chain
        ) else {
            presenter?.didDecideMonitoredExecution(for: model)
            return
        }

        let wrapper = assetsExchangeService.submitSingleOperationWrapper(using: model.fee)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter?.didCompleteSwapSubmission(with: result)
        }
    }
}
