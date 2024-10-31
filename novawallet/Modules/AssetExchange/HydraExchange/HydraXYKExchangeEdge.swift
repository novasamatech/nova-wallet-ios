import Foundation
import Operation_iOS

final class AssetsHydraXYKExchangeEdge: AssetsHydraExchangeEdge {
    let quoteFactory: HydraXYKSwapQuoteFactory

    init(
        origin: ChainAssetId,
        destination: ChainAssetId,
        remoteSwapPair: HydraDx.RemoteSwapPair,
        quoteFactory: HydraXYKSwapQuoteFactory
    ) {
        self.quoteFactory = quoteFactory

        super.init(
            origin: origin,
            destination: destination,
            remoteSwapPair: remoteSwapPair
        )
    }
}

extension AssetsHydraXYKExchangeEdge: AssetsHydraExchangeEdgeProtocol {
    var routeComponent: HydraDx.RemoteSwapRoute.Component {
        .init(
            assetIn: remoteSwapPair.assetIn,
            assetOut: remoteSwapPair.assetOut,
            type: .xyk
        )
    }
}

extension AssetsHydraXYKExchangeEdge: AssetExchangableGraphEdge {
    var weight: Int { 1 }

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
}
