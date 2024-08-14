import Foundation
import Operation_iOS
import SubstrateSdk

final class ExtrinsicAssetsCustomFeeEstimator {
    let chainAsset: ChainAsset
    let operationQueue: OperationQueue

    init(
        chainAsset: ChainAsset,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.operationQueue = operationQueue
    }
}

extension ExtrinsicAssetsCustomFeeEstimator: ExtrinsicFeeEstimating {
    func createFeeEstimatingWrapper(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        guard
            let nativeAssetId = chainAsset.chain.utilityChainAssetId() else {
            return CompoundOperationWrapper.createWithError(ExtrinsicFeeEstimatingError.brokenFee)
        }

        let assetOutId = chainAsset.chainAssetId

        let nativeEstimator = ExtrinsicNativeFeeEstimator(
            chain: chainAsset.chain,
            operationQueue: operationQueue
        ).createFeeEstimatingWrapper(
            connection: connection,
            runtimeService: runtimeService,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )

        let quoteFactory = AssetHubSwapOperationFactory(
            chain: chainAsset.chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )

        let conversionOperation: BaseOperation<[AssetConversion.Quote]> = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let nativeFees = try nativeEstimator.targetOperation.extractNoCancellableResultData().items

            return nativeFees.map { nativeFee in
                let quoteArgs = AssetConversion.QuoteArgs(
                    assetIn: assetOutId,
                    assetOut: nativeAssetId,
                    amount: nativeFee.amount,
                    direction: .buy
                )

                return quoteFactory.quote(for: quoteArgs)
            }
        }.longrunOperation()

        conversionOperation.addDependency(nativeEstimator.targetOperation)

        let mapOperation = ClosureOperation<ExtrinsicFeeEstimationResultProtocol> {
            let nativeFees = try nativeEstimator.targetOperation.extractNoCancellableResultData().items
            let quotes = try conversionOperation.extractNoCancellableResultData()

            let items = zip(nativeFees, quotes).map { pair in
                ExtrinsicFee(amount: pair.1.amountIn, payer: pair.0.payer, weight: pair.0.weight)
            }

            return ExtrinsicFeeEstimationResult(items: items)
        }

        mapOperation.addDependency(conversionOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: nativeEstimator.allOperations + [conversionOperation]
        )
    }
}