import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraFeeService {
    let extrinsicFactory: ExtrinsicOperationFactoryProtocol
    let conversionOperationFactory: HydraQuoteFactory
    let conversionExtrinsicFactory: HydraExtrinsicOperationFactoryProtocol
    let workQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var feeCall = CancellableCallStore()
    private let mutex = NSLock()

    init(
        extrinsicFactory: ExtrinsicOperationFactoryProtocol,
        conversionOperationFactory: HydraQuoteFactory,
        conversionExtrinsicFactory: HydraExtrinsicOperationFactoryProtocol,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue = .global()
    ) {
        self.extrinsicFactory = extrinsicFactory
        self.conversionOperationFactory = conversionOperationFactory
        self.conversionExtrinsicFactory = conversionExtrinsicFactory
        self.operationQueue = operationQueue
        self.workQueue = workQueue
    }

    deinit {
        feeCall.cancel()
    }

    private func createNativeFeeWrapper(
        paramsOperation: BaseOperation<HydraSwapParams>
    ) -> CompoundOperationWrapper<FeeIndexedExtrinsicResult> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let swap = try paramsOperation.extractNoCancellableResultData()

            return self.extrinsicFactory.estimateFeeOperation({ builder, index in
                if index == 0, swap.params.shouldSetFeeCurrency {
                    return try HydraExtrinsicConverter.addingSetCurrencyCall(
                        from: swap,
                        builder: builder
                    )
                } else {
                    return try HydraExtrinsicConverter.addingOperation(
                        from: swap,
                        builder: builder
                    )
                }
            }, numberOfExtrinsics: swap.numberOfExtrinsics)
        }
    }

    private func createNonNativeFeeWrapper(
        for nativeFee: ExtrinsicFeeProtocol,
        feeAsset: ChainAsset
    ) -> CompoundOperationWrapper<AssetConversion.FeeModel> {
        guard let utilityAssetId = feeAsset.chain.utilityChainAssetId() else {
            return CompoundOperationWrapper<AssetConversion.FeeModel>.createWithError(
                AssetConversionFeeServiceError.feeAssetConversionFailed
            )
        }

        let quoteWrapper = conversionOperationFactory.quote(
            for: .init(
                assetIn: feeAsset.chainAssetId,
                assetOut: utilityAssetId,
                amount: nativeFee.amount,
                direction: .buy
            )
        )

        /**
         *      We are adding ed to final fee amount as currently runtime has a bug that leads to extrinsic fail
         *      when fee paid in non native asset and balance goes below ed.
         */
        let balanceExistenceWrapper = AssetStorageInfoOperationFactory().createAssetBalanceExistenceOperation(
            chainId: feeAsset.chain.chainId,
            asset: feeAsset.asset,
            runtimeProvider: conversionOperationFactory.flowState.runtimeProvider,
            operationQueue: conversionOperationFactory.flowState.operationQueue
        )

        let mappingOperation = ClosureOperation<AssetConversion.FeeModel> {
            let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()
            let balanceExistence = try balanceExistenceWrapper.targetOperation.extractNoCancellableResultData()

            let model = AssetConversion.AmountWithNative(
                targetAmount: quote.amountIn + balanceExistence.minBalance,
                nativeAmount: quote.amountOut
            )

            return .init(totalFee: model, networkFee: model, networkFeePayer: nativeFee.payer)
        }

        mappingOperation.addDependency(balanceExistenceWrapper.targetOperation)
        mappingOperation.addDependency(quoteWrapper.targetOperation)

        return quoteWrapper
            .insertingHead(operations: balanceExistenceWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }

    private func createConversionWrapper(
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

            return self.createNonNativeFeeWrapper(for: totalFee, feeAsset: feeAsset)
        }
    }
}

extension HydraFeeService: AssetConversionFeeServiceProtocol {
    func calculate(
        in asset: ChainAsset,
        callArgs: AssetConversion.CallArgs,
        runCompletionIn queue: DispatchQueue,
        completion closure: @escaping AssetConversionFeeServiceClosure
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        feeCall.cancel()

        let paramsWrapper = conversionExtrinsicFactory.createOperationWrapper(
            for: asset,
            callArgs: callArgs
        )

        let nativeFeeWrapper = createNativeFeeWrapper(
            paramsOperation: paramsWrapper.targetOperation
        )

        nativeFeeWrapper.addDependency(wrapper: paramsWrapper)

        let conversionWrapper = createConversionWrapper(
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
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { result in
            dispatchInQueueWhenPossible(queue) {
                do {
                    let model = try result.get()
                    closure(.success(model))
                } catch let error as AssetConversionFeeServiceError {
                    closure(.failure(error))
                } catch {
                    closure(.failure(.calculationFailed("Fee calculation error: \(error)")))
                }
            }
        }
    }
}
