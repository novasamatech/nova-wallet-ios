import UIKit
import RobinHood

final class SwapConfirmInteractor: SwapBaseInteractor {
    var presenter: SwapConfirmInteractorOutputProtocol? {
        basePresenter as? SwapConfirmInteractorOutputProtocol
    }

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

    override func setup() {
        super.setup()

        set(payChainAsset: initState.chainAssetIn)
        set(receiveChainAsset: initState.chainAssetOut)
        set(feeChainAsset: initState.feeChainAsset)
    }

    func submitExtrinsic(args: AssetConversion.CallArgs) {
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
                    try self.submitClosure(builder: builder, runtimeCoderFactory: runtimeCoderFactory)
                } catch {
                    self.presenter?.didReceive(error: .submit(error))
                }
            }
        }

        operationQueue.addOperation(runtimeCoderFactoryOperation)
    }

    private func submitClosure(
        builder: @escaping ExtrinsicBuilderClosure,
        runtimeCoderFactory: RuntimeCoderFactoryProtocol
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
                self?.presenter?.didReceiveConfirmation(hash: hash)
            case let .failure(error):
                self?.presenter?.didReceive(error: .submit(error))
            }
        }
    }
}

extension SwapConfirmInteractor: SwapConfirmInteractorInputProtocol {
    func submit(args: AssetConversion.CallArgs) {
        submitExtrinsic(args: args)
    }
}
