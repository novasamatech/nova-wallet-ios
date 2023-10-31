import UIKit
import RobinHood

final class SwapConfirmInteractor: SwapBaseInteractor {
    var presenter: SwapConfirmInteractorOutputProtocol? {
        basePresenter as? SwapConfirmInteractorOutputProtocol
    }

    let initState: SwapConfirmInitState
    let runtimeService: RuntimeProviderProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let assetConversionExtrinsicService: AssetConversionExtrinsicServiceProtocol
    let signer: SigningWrapperProtocol
    let operationQueue: OperationQueue

    init(
        initState: SwapConfirmInitState,
        assetConversionFeeService: AssetConversionFeeServiceProtocol,
        assetConversionOperationFactory: AssetConversionOperationFactoryProtocol,
        assetConversionExtrinsicService: AssetConversionExtrinsicServiceProtocol,
        runtimeService: RuntimeProviderProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        selectedWallet: MetaAccountModel,
        operationQueue: OperationQueue,
        signer: SigningWrapperProtocol
    ) {
        self.initState = initState
        self.signer = signer
        self.operationQueue = operationQueue
        self.runtimeService = runtimeService
        self.extrinsicService = extrinsicService
        self.assetConversionExtrinsicService = assetConversionExtrinsicService

        super.init(
            assetConversionOperationFactory: assetConversionOperationFactory,
            assetConversionFeeService: assetConversionFeeService,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
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
                    self.submitClosure(extrinsicService: self.extrinsicService, builder: builder)
                } catch {
                    self.presenter?.didReceive(error: .submit(error))
                }
            }
        }

        operationQueue.addOperation(runtimeCoderFactoryOperation)
    }

    private func submitClosure(
        extrinsicService: ExtrinsicServiceProtocol,
        builder: @escaping ExtrinsicBuilderClosure
    ) {
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
