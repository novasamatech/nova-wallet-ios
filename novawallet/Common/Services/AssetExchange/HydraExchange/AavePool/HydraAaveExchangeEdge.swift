import Foundation
import Operation_iOS

final class HydraAaveExchangeEdge: AssetsHydraExchangeEdge {
    let quoteFactory: HydraAaveSwapQuoteFactory

    init(
        origin: ChainAssetId,
        destination: ChainAssetId,
        remoteSwapPair: HydraDx.RemoteSwapPair,
        host: HydraExchangeHostProtocol,
        quoteFactory: HydraAaveSwapQuoteFactory
    ) {
        self.quoteFactory = quoteFactory

        super.init(
            origin: origin,
            destination: destination,
            remoteSwapPair: remoteSwapPair,
            host: host
        )
    }
}

extension HydraAaveExchangeEdge: AssetsHydraExchangeEdgeProtocol {
    var routeComponent: HydraDx.RemoteSwapRoute.Component {
        HydraDx.RemoteSwapRoute.Component(
            assetIn: remoteSwapPair.assetIn,
            assetOut: remoteSwapPair.assetOut,
            type: .aave
        )
    }
}

extension HydraAaveExchangeEdge: AssetExchangableGraphEdge {
    var weight: Int { AssetsExchange.defaultEdgeWeight - 10 }

    func addingWeight(to currentWeight: Int, predecessor edge: AnyGraphEdgeProtocol?) -> Int {
        addingWeight(to: currentWeight, predecessor: edge, suggestedEdgeWeight: weight)
    }

    func quote(
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<Balance> {
        quoteFactory.quote(
            for: .init(
                assetIn: remoteSwapPair.assetIn,
                assetOut: remoteSwapPair.assetOut,
                amount: amount,
                direction: direction
            )
        )
    }

    func beginOperation(for args: AssetExchangeAtomicOperationArgs) throws -> AssetExchangeAtomicOperationProtocol {
        HydraExchangeAtomicOperation(
            host: host,
            operationArgs: args,
            edges: [self]
        )
    }

    func appendToOperation(
        _ operation: AssetExchangeAtomicOperationProtocol,
        args: AssetExchangeAtomicOperationArgs
    ) -> AssetExchangeAtomicOperationProtocol? {
        appendToOperation(
            operation,
            edge: self,
            args: args
        )
    }
}
