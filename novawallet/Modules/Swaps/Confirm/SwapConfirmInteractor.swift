import UIKit
import RobinHood
import IrohaCrypto
import BigInt

final class SwapConfirmInteractor: SwapBaseInteractor {
    var presenter: SwapConfirmInteractorOutputProtocol? {
        basePresenter as? SwapConfirmInteractorOutputProtocol
    }

    let persistExtrinsicService: PersistentExtrinsicServiceProtocol
    let eventCenter: EventCenterProtocol
    let initState: SwapConfirmInitState
    let runtimeService: RuntimeProviderProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let assetConversionExtrinsicService: AssetConversionExtrinsicServiceProtocol
    let signer: SigningWrapperProtocol

    init(
        initState: SwapConfirmInitState,
        assetConversionFeeService: AssetConversionFeeServiceProtocol,
        assetConversionAggregator: AssetConversionAggregationFactoryProtocol,
        assetConversionExtrinsicService: AssetConversionExtrinsicServiceProtocol,
        chainRegistry: ChainRegistryProtocol,
        assetStorageFactory: AssetStorageInfoOperationFactoryProtocol,
        runtimeService: RuntimeProviderProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        persistExtrinsicService: PersistentExtrinsicServiceProtocol,
        eventCenter: EventCenterProtocol,
        currencyManager: CurrencyManagerProtocol,
        selectedWallet: MetaAccountModel,
        operationQueue: OperationQueue,
        signer: SigningWrapperProtocol
    ) {
        self.initState = initState
        self.signer = signer
        self.runtimeService = runtimeService
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.assetConversionExtrinsicService = assetConversionExtrinsicService
        self.persistExtrinsicService = persistExtrinsicService
        self.eventCenter = eventCenter

        super.init(
            assetConversionAggregator: assetConversionAggregator,
            assetConversionFeeService: assetConversionFeeService,
            chainRegistry: chainRegistry,
            assetStorageFactory: assetStorageFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            generalSubscriptionFactory: generalLocalSubscriptionFactory,
            currencyManager: currencyManager,
            selectedWallet: selectedWallet,
            operationQueue: operationQueue
        )
    }

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
                receive: receiver,
                assetIdIn: args.assetIn,
                amountIn: args.amountIn,
                assetIdOut: args.assetOut,
                amountOut: args.amountOut,
                fee: lastFee,
                feeAssetId: initState.feeChainAsset.asset.assetId,
                callPath: AssetConversionPallet.callPath(for: args.direction)
            )

            persistExtrinsicService.saveSwap(
                source: .substrate,
                chainAssetId: details.assetIdIn,
                details: details,
                runningIn: .main
            ) { [weak self] _ in
                self?.eventCenter.notify(with: WalletTransactionListUpdated())
                self?.presenter?.didReceiveConfirmation(hash: txHash)
            }
        } catch {
            // complete successfully as we don't want a user to think tx is failed
            presenter?.didReceiveConfirmation(hash: txHash)
        }
    }

    override func setup() {
        super.setup()

        set(payChainAsset: initState.chainAssetIn)
        set(receiveChainAsset: initState.chainAssetOut)
        set(feeChainAsset: initState.feeChainAsset)
    }

    func submitExtrinsic(args: AssetConversion.CallArgs, lastFee: BigUInt?) {
        let runtimeCoderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        runtimeCoderFactoryOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                do {
                    let runtimeCoderFactory = try runtimeCoderFactoryOperation.extractNoCancellableResultData()
                    let builder = self.assetConversionExtrinsicService.fetchExtrinsicBuilderClosure(
                        for: args,
                        codingFactory: runtimeCoderFactory
                    )
                    try self.submitClosure(
                        builder: builder,
                        runtimeCoderFactory: runtimeCoderFactory,
                        args: args,
                        lastFee: lastFee
                    )
                } catch {
                    self.presenter?.didReceive(error: .submit(error))
                }
            }
        }

        operationQueue.addOperation(runtimeCoderFactoryOperation)
    }

    private func submitClosure(
        builder: @escaping ExtrinsicBuilderClosure,
        runtimeCoderFactory: RuntimeCoderFactoryProtocol,
        args: AssetConversion.CallArgs,
        lastFee: BigUInt?
    ) throws {
        let extrinsicService: ExtrinsicServiceProtocol

        guard let account = chainAccountResponse(for: initState.feeChainAsset) else {
            throw ChainAccountFetchingError.accountNotExists
        }

        if initState.feeChainAsset.isUtilityAsset {
            extrinsicService = extrinsicServiceFactory.createService(
                account: account,
                chain: initState.feeChainAsset.chain
            )
        } else {
            guard let assetId = AssetHubTokensConverter.convertToMultilocation(
                chainAsset: initState.feeChainAsset,
                codingFactory: runtimeCoderFactory
            ) else {
                throw SwapConfirmError.submit(CommonError.dataCorruption)
            }

            extrinsicService = extrinsicServiceFactory.createService(
                account: account,
                chain: initState.feeChainAsset.chain,
                feeAssetConversionId: assetId
            )
        }

        extrinsicService.submit(
            builder,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(hash):
                self?.persistSwapAndComplete(
                    txHash: hash,
                    args: args,
                    lastFee: lastFee
                )
            case let .failure(error):
                self?.presenter?.didReceive(error: .submit(error))
            }
        }
    }
}

extension SwapConfirmInteractor: SwapConfirmInteractorInputProtocol {
    func submit(args: AssetConversion.CallArgs, lastFee: BigUInt?) {
        submitExtrinsic(args: args, lastFee: lastFee)
    }
}
