import Foundation
import Operation_iOS

final class AssetHubExchangeEdge {
    let origin: ChainAssetId
    let destination: ChainAssetId
    let quoteFactory: AssetHubSwapOperationFactoryProtocol

    init(origin: ChainAssetId, destination: ChainAssetId, quoteFactory: AssetHubSwapOperationFactoryProtocol) {
        self.origin = origin
        self.destination = destination
        self.quoteFactory = quoteFactory
    }
}

extension AssetHubExchangeEdge: AssetExchangableGraphEdge {
    var weight: Int { 1 }

    func quote(
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<Balance> {
        let quoteArgs = AssetConversion.QuoteArgs(
            assetIn: origin,
            assetOut: destination,
            amount: amount,
            direction: direction
        )

        let quoteWrapper = quoteFactory.quote(for: quoteArgs)

        let mappingOperation = ClosureOperation<Balance> {
            try quoteWrapper.targetOperation.extractNoCancellableResultData().amountOut
        }

        mappingOperation.addDependency(quoteWrapper.targetOperation)

        return quoteWrapper.insertingTail(operation: mappingOperation)
    }
}
