import UIKit
import Operation_iOS
import IrohaCrypto
import BigInt

final class SwapConfirmInteractor: SwapBaseInteractor {
    var presenter: SwapConfirmInteractorOutputProtocol? {
        basePresenter as? SwapConfirmInteractorOutputProtocol
    }

    let persistExtrinsicService: PersistentExtrinsicServiceProtocol
    let eventCenter: EventCenterProtocol
    let initState: SwapConfirmInitState
    let signer: SigningWrapperProtocol
    let callPathFactory: AssetConversionCallPathFactoryProtocol

    init(
        state: SwapTokensFlowStateProtocol,
        initState: SwapConfirmInitState,
        chainRegistry: ChainRegistryProtocol,
        assetStorageFactory: AssetStorageInfoOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        persistExtrinsicService: PersistentExtrinsicServiceProtocol,
        eventCenter: EventCenterProtocol,
        currencyManager: CurrencyManagerProtocol,
        selectedWallet: MetaAccountModel,
        operationQueue: OperationQueue,
        signer: SigningWrapperProtocol,
        callPathFactory: AssetConversionCallPathFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.initState = initState
        self.signer = signer
        self.persistExtrinsicService = persistExtrinsicService
        self.eventCenter = eventCenter
        self.callPathFactory = callPathFactory

        super.init(
            state: state,
            chainRegistry: chainRegistry,
            assetStorageFactory: assetStorageFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            currencyManager: currencyManager,
            selectedWallet: selectedWallet,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    // TODO: Fix swap persisting
    private func persistSwapAndComplete(txHash: String, args: AssetConversion.CallArgs, lastFee: BigUInt?) {
        do {
            let chainIn = initState.chainAssetIn.chain

            guard let sender = selectedWallet.fetch(for: chainIn.accountRequest())?.toAddress() else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let receiver = try args.receiver.toAddress(using: initState.chainAssetOut.chain.chainFormat)

            let details = PersistSwapDetails(
                txHash: try Data(hexString: txHash),
                sender: sender,
                receiver: receiver,
                assetIdIn: args.assetIn,
                amountIn: args.amountIn,
                assetIdOut: args.assetOut,
                amountOut: args.amountOut,
                fee: lastFee,
                feeAssetId: initState.feeChainAsset.asset.assetId,
                callPath: callPathFactory.createHistoryCallPath(for: args)
            )

            persistExtrinsicService.saveSwap(
                source: .substrate,
                chainAssetId: details.assetIdIn,
                details: details,
                runningIn: .main
            ) { [weak self] _ in
                self?.eventCenter.notify(with: WalletTransactionListUpdated())
            }
        } catch {
            // complete successfully as we don't want a user to think tx is failed
        }
    }

    override func setup() {
        super.setup()

        set(payChainAsset: initState.chainAssetIn)
        set(receiveChainAsset: initState.chainAssetOut)
        set(feeChainAsset: initState.feeChainAsset)
    }
}

extension SwapConfirmInteractor: SwapConfirmInteractorInputProtocol {
    func submit(using estimation: AssetExchangeFee) {
        let wrapper = assetsExchangeService.submit(using: estimation)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(amount):
                self?.presenter?.didReceiveSwaped(amount: amount)
            case let .failure(error):
                self?.presenter?.didReceive(error: .submit(error))
            }
        }
    }
}
