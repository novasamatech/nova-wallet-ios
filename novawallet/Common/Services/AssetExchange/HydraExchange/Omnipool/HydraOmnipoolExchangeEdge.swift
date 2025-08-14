import Foundation
import Operation_iOS

final class HydraOmnipoolExchangeEdge: AssetsHydraExchangeEdge {
    let quoteFactory: HydraOmnipoolQuoteFactory

    init(
        origin: ChainAssetId,
        destination: ChainAssetId,
        remoteSwapPair: HydraDx.RemoteSwapPair,
        host: HydraExchangeHostProtocol,
        quoteFactory: HydraOmnipoolQuoteFactory
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

extension HydraOmnipoolExchangeEdge: AssetsHydraExchangeEdgeProtocol {
    var routeComponent: HydraDx.RemoteSwapRoute.Component {
        .init(
            assetIn: remoteSwapPair.assetIn,
            assetOut: remoteSwapPair.assetOut,
            type: .omnipool
        )
    }
}

extension HydraOmnipoolExchangeEdge: AssetExchangableGraphEdge {
    var weight: Int { AssetsExchange.defaultEdgeWeight }

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
