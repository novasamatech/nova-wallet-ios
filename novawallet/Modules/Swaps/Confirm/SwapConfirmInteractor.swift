import UIKit
import RobinHood

final class SwapConfirmInteractor: SwapBaseInteractor {
    var presenter: SwapConfirmInteractorOutputProtocol? {
        basePresenter as? SwapConfirmInteractorOutputProtocol
    }

    let initState: SwapConfirmInitState
    let signer: SigningWrapperProtocol
    let operationQueue: OperationQueue
    private var submitOperationCall: CancellableCall?

    init(
        initState: SwapConfirmInitState,
        assetConversionOperationFactory: AssetConversionOperationFactoryProtocol,
        assetConversionExtrinsicService: AssetConversionExtrinsicServiceProtocol,
        runtimeService: RuntimeProviderProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        selectedAccount: MetaAccountModel,
        operationQueue: OperationQueue,
        signer: SigningWrapperProtocol
    ) {
        self.initState = initState
        self.signer = signer
        self.operationQueue = operationQueue

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

        set(payChainAsset: initState.chainAssetIn)
        set(receiveChainAsset: initState.chainAssetOut)
        set(feeChainAsset: initState.feeChainAsset)
    }

    func submitExtrinsic(args: AssetConversion.CallArgs) {
        clear(cancellable: &submitOperationCall)
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
                self.submitClosure(extrinsicService: extrinsicService, builder: builder)
            } catch {
                DispatchQueue.main.async {
                    self.presenter?.didReceive(error: .submit(error))
                }
            }
        }

        submitOperationCall = runtimeCoderFactoryOperation
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
