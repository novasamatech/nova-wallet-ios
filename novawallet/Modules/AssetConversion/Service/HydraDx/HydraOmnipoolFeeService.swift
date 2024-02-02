import Foundation
import SubstrateSdk
import RobinHood

final class HydraOmnipoolFeeService {
    struct ChainOperationFactory {
        let extrinsicFactory: ExtrinsicOperationFactoryProtocol
        let conversionOperationFactory: AssetConversionOperationFactoryProtocol
        let conversionExtrinsicFactory: HydraOmnipoolExtrinsicOperationFactoryProtocol
    }

    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let userStorageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue

    private var chainId: ChainModel.Id?
    private var factories: ChainOperationFactory?
    private var feeCall = CancellableCallStore()
    private var mutex = NSLock()

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        userStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.userStorageFacade = userStorageFacade
        self.operationQueue = operationQueue
    }

    deinit {
        feeCall.cancel()
    }

    private func updateFactories(for chain: ChainModel) throws -> ChainOperationFactory {
        if chain.chainId == chainId, let factories = factories {
            return factories
        }

        factories = nil
        chainId = nil

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw AssetConversionFeeServiceError.chainConnectionMissing
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw AssetConversionFeeServiceError.chainRuntimeMissing
        }

        guard let account = wallet.fetch(for: chain.accountRequest()) else {
            throw AssetConversionFeeServiceError.accountMissing
        }

        let extrinsicFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue),
            userStorageFacade: userStorageFacade
        ).createOperationFactory(
            account: account,
            chain: chain
        )

        let conversionOperationFactory = HydraOmnipoolOperationFactory(
            chain: chain,
            runtimeService: runtimeProvider,
            connection: connection,
            operationQueue: operationQueue
        )

        let swapService = HydraOmnipoolSwapService(
            accountId: account.accountId,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        let swapOperationFactory = HydraOmnipoolExtrinsicOperationFactory(
            chain: chain,
            swapService: swapService,
            runtimeProvider: runtimeProvider
        )

        let factories = ChainOperationFactory(
            extrinsicFactory: extrinsicFactory,
            conversionOperationFactory: conversionOperationFactory,
            conversionExtrinsicFactory: swapOperationFactory
        )

        self.factories = factories
        chainId = chain.chainId

        swapService.setup()

        return factories
    }

    private func createNativeFeeWrapper(
        factories: ChainOperationFactory,
        paramsOperation: BaseOperation<HydraOmnipoolSwapParams>
    ) -> CompoundOperationWrapper<FeeIndexedExtrinsicResult> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let swap = try paramsOperation.extractNoCancellableResultData()

            let operationFactory = factories.extrinsicFactory

            return operationFactory.estimateFeeOperation({ builder, index in
                if index == 0, swap.params.shouldSetFeeCurrency {
                    return try HydraOmnipoolExtrinsicConverter.addingSetCurrencyCall(
                        from: swap,
                        builder: builder
                    )
                } else {
                    return try HydraOmnipoolExtrinsicConverter.addingOperation(
                        from: swap,
                        builder: builder
                    )
                }
            }, numberOfExtrinsics: swap.numberOfExtrinsics)
        }
    }

    private func createNonNativeFeeWrapper(
        for nativeFee: ExtrinsicFeeProtocol,
        feeAsset: ChainAsset,
        factories: ChainOperationFactory
    ) -> CompoundOperationWrapper<AssetConversion.FeeModel> {
        guard let utilityAssetId = feeAsset.chain.utilityChainAssetId() else {
            return CompoundOperationWrapper<AssetConversion.FeeModel>.createWithError(
                AssetConversionFeeServiceError.feeAssetConversionFailed
            )
        }

        let quoteWrapper = factories.conversionOperationFactory.quote(
            for: .init(
                assetIn: utilityAssetId,
                assetOut: feeAsset.chainAssetId,
                amount: nativeFee.amount,
                direction: .sell
            )
        )

        let mappingOperation = ClosureOperation<AssetConversion.FeeModel> {
            let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()

            let model = AssetConversion.AmountWithNative(
                targetAmount: quote.amountOut,
                nativeAmount: quote.amountIn
            )

            return .init(totalFee: model, networkFee: model, networkFeePayer: nativeFee.payer)
        }

        mappingOperation.addDependency(quoteWrapper.targetOperation)

        return quoteWrapper.insertingTail(operation: mappingOperation)
    }

    private func createConversionWrapper(
        factories: ChainOperationFactory,
        nativeFeeOperation: BaseOperation<FeeIndexedExtrinsicResult>,
        feeAsset: ChainAsset
    ) -> CompoundOperationWrapper<AssetConversion.FeeModel> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let feeResult = try nativeFeeOperation.extractNoCancellableResultData()

            let optTotalFee: ExtrinsicFeeProtocol? = try feeResult.results.reduce(nil) { accum, feeResult in
                let fee = try feeResult.result.get()

                if let currentFee = accum {
                    return ExtrinsicFee(
                        amount: currentFee.amount + fee.amount,
                        payer: fee.payer,
                        weight: currentFee.weight + fee.weight
                    )
                } else {
                    return ExtrinsicFee(
                        amount: fee.amount,
                        payer: fee.payer,
                        weight: fee.weight
                    )
                }
            }

            guard let totalFee = optTotalFee else {
                return CompoundOperationWrapper<AssetConversion.FeeModel>.createWithError(
                    AssetConversionFeeServiceError.calculationFailed("Missing fee")
                )
            }

            guard !feeAsset.isUtilityAsset else {
                let model = AssetConversion.AmountWithNative(
                    targetAmount: totalFee.amount,
                    nativeAmount: totalFee.amount
                )

                let convertedFee = AssetConversion.FeeModel(
                    totalFee: model,
                    networkFee: model,
                    networkFeePayer: totalFee.payer
                )

                return CompoundOperationWrapper.createWithResult(convertedFee)
            }

            return self.createNonNativeFeeWrapper(for: totalFee, feeAsset: feeAsset, factories: factories)
        }
    }
}

extension HydraOmnipoolFeeService: AssetConversionFeeServiceProtocol {
    func calculate(
        in asset: ChainAsset,
        callArgs: AssetConversion.CallArgs,
        runCompletionIn queue: DispatchQueue,
        completion closure: @escaping AssetConversionFeeServiceClosure
    ) {
        do {
            mutex.lock()

            defer {
                mutex.unlock()
            }

            feeCall.cancel()
            let factories = try updateFactories(for: asset.chain)

            let paramsWrapper = factories.conversionExtrinsicFactory.createOperationWrapper(
                for: asset,
                callArgs: callArgs
            )

            let nativeFeeWrapper = createNativeFeeWrapper(
                factories: factories,
                paramsOperation: paramsWrapper.targetOperation
            )

            nativeFeeWrapper.addDependency(wrapper: paramsWrapper)

            let conversionWrapper = createConversionWrapper(
                factories: factories,
                nativeFeeOperation: nativeFeeWrapper.targetOperation,
                feeAsset: asset
            )

            conversionWrapper.addDependency(wrapper: nativeFeeWrapper)
            conversionWrapper.addDependency(wrapper: paramsWrapper)

            let dependencies = paramsWrapper.allOperations + nativeFeeWrapper.allOperations +
                conversionWrapper.dependencies

            let finalWrapper = CompoundOperationWrapper(
                targetOperation: conversionWrapper.targetOperation,
                dependencies: dependencies
            )

            executeCancellable(
                wrapper: finalWrapper,
                inOperationQueue: operationQueue,
                backingCallIn: feeCall,
                runningCallbackIn: queue,
                mutex: mutex
            ) { result in
                do {
                    let model = try result.get()
                    closure(.success(model))
                } catch let error as AssetConversionFeeServiceError {
                    closure(.failure(error))
                } catch {
                    closure(.failure(.calculationFailed("Fee calculation error: \(error)")))
                }
            }

        } catch {
            dispatchInQueueWhenPossible(queue) {
                closure(.failure(.setupFailed("Fee service setup failed for \(asset.chain.name): \(error)")))
            }
        }
    }
}
