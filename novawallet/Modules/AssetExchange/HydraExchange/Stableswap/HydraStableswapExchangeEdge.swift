import Foundation
import Operation_iOS

final class HydraStableswapExchangeEdge: AssetsHydraExchangeEdge {
    let quoteFactory: HydraStableswapQuoteFactory
    let poolAsset: HydraDx.AssetId

    init(
        origin: ChainAssetId,
        destination: ChainAssetId,
        remoteSwapPair: HydraDx.RemoteSwapPair,
        poolAsset: HydraDx.AssetId,
        host: HydraExchangeHostProtocol,
        quoteFactory: HydraStableswapQuoteFactory
    ) {
        self.quoteFactory = quoteFactory
        self.poolAsset = poolAsset

        super.init(
            origin: origin,
            destination: destination,
            remoteSwapPair: remoteSwapPair,
            host: host
        )
    }
}

extension HydraStableswapExchangeEdge: AssetsHydraExchangeEdgeProtocol {
    var routeComponent: HydraDx.RemoteSwapRoute.Component {
        .init(
            assetIn: remoteSwapPair.assetIn,
            assetOut: remoteSwapPair.assetOut,
            type: .stableswap(poolAsset)
        )
    }
}

extension HydraStableswapExchangeEdge: AssetExchangableGraphEdge {
    var weight: Int { AssetsExchange.defaultEdgeWeight - 1 }

    func quote(
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<Balance> {
        quoteFactory.quote(
            for: .init(
                assetIn: remoteSwapPair.assetIn,
                assetOut: remoteSwapPair.assetOut,
                poolAsset: poolAsset,
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
