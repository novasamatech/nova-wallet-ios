import Foundation

final class AssetExchangeFeeEstimatingFactory {
    let runtimeConversionFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol?
    let graphProxy: AssetQuoteFactoryProtocol
    let operationQueue: OperationQueue
    let feeBufferInPercentage: BigRational

    init(
        graphProxy: AssetQuoteFactoryProtocol,
        operationQueue: OperationQueue,
        feeBufferInPercentage: BigRational,
        runtimeConversionFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol? = nil
    ) {
        self.graphProxy = graphProxy
        self.operationQueue = operationQueue
        self.feeBufferInPercentage = feeBufferInPercentage
        self.runtimeConversionFactory = runtimeConversionFactory
    }
}

extension AssetExchangeFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol {
    func createCustomFeeEstimator(for chainAsset: ChainAsset) -> ExtrinsicFeeEstimating? {
        if let estimator = runtimeConversionFactory?.createCustomFeeEstimator(for: chainAsset) {
            return estimator
        }

        return ExtrinsicAssetConversionFeeEstimator(
            chainAsset: chainAsset,
            operationQueue: operationQueue,
            quoteFactory: graphProxy,
            feeBufferInPercentage: feeBufferInPercentage
        )
    }
}
