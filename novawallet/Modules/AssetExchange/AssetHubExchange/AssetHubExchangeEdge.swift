import Foundation
import Operation_iOS

final class AssetHubExchangeEdge {
    let origin: ChainAssetId
    let destination: ChainAssetId
    let quoteFactory: AssetHubSwapOperationFactoryProtocol
    let host: AssetHubExchangeHostProtocol

    init(
        origin: ChainAssetId,
        destination: ChainAssetId,
        quoteFactory: AssetHubSwapOperationFactoryProtocol,
        host: AssetHubExchangeHostProtocol
    ) {
        self.origin = origin
        self.destination = destination
        self.quoteFactory = quoteFactory
        self.host = host
    }
}

extension AssetHubExchangeEdge: AssetExchangableGraphEdge {
    var weight: Int { AssetsExchange.defaultEdgeWeight + 1 }

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

    func beginOperation(for args: AssetExchangeAtomicOperationArgs) throws -> AssetExchangeAtomicOperationProtocol {
        AssetHubExchangeAtomicOperation(
            host: host,
            operationArgs: args,
            edge: self
        )
    }

    func appendToOperation(
        _: AssetExchangeAtomicOperationProtocol,
        args _: AssetExchangeAtomicOperationArgs
    ) -> AssetExchangeAtomicOperationProtocol? {
        nil
    }

    func shouldIgnoreFeeRequirement(after _: any AssetExchangableGraphEdge) -> Bool {
        false
    }

    func canPayNonNativeFeesInIntermediatePosition() -> Bool {
        // TODO: assetIn is must be self sufficient
        true
    }
}
