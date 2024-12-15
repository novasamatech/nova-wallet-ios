import Foundation

final class AssetExchangeFeeEstimatingFactory {
    let graphProxy: AssetQuoteFactoryProtocol
    let operationQueue: OperationQueue

    // we 10% buffer for fee since swaps to native asset especially volatile
    let feeBuffer = BigRational.percent(of: 10)

    init(graphProxy: AssetQuoteFactoryProtocol, operationQueue: OperationQueue) {
        self.graphProxy = graphProxy
        self.operationQueue = operationQueue
    }
}

extension AssetExchangeFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol {
    func createCustomFeeEstimator(for chainAsset: ChainAsset) -> ExtrinsicFeeEstimating? {
        ExtrinsicAssetConversionFeeEstimator(
            chainAsset: chainAsset,
            operationQueue: operationQueue,
            quoteFactory: graphProxy,
            feeBufferInPercentage: feeBuffer
        )
    }
}
