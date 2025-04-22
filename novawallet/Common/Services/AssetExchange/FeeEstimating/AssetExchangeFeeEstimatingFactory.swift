import Foundation

final class AssetExchangeFeeEstimatingFactory {
    let graphProxy: AssetQuoteFactoryProtocol
    let operationQueue: OperationQueue
    let feeBufferInPercentage: BigRational

    init(
        graphProxy: AssetQuoteFactoryProtocol,
        operationQueue: OperationQueue,
        feeBufferInPercentage: BigRational
    ) {
        self.graphProxy = graphProxy
        self.operationQueue = operationQueue
        self.feeBufferInPercentage = feeBufferInPercentage
    }
}

extension AssetExchangeFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol {
    func createCustomFeeEstimator(for chainAsset: ChainAsset) -> ExtrinsicFeeEstimating? {
        ExtrinsicAssetConversionFeeEstimator(
            chainAsset: chainAsset,
            operationQueue: operationQueue,
            quoteFactory: graphProxy,
            feeBufferInPercentage: feeBufferInPercentage
        )
    }
}
