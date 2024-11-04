import Foundation

final class AssetExchangeFeeEstimatingFactory {
    let graphProxy: AssetQuoteFactoryProtocol
    let operationQueue: OperationQueue

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
            quoteFactory: graphProxy
        )
    }
}
