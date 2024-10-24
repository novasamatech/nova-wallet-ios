import Foundation
import Operation_iOS

final class AssetsHydraStableswapExchangeEdge: AssetsHydraExchangeEdge {
    let quoteFactory: HydraStableswapQuoteFactory
    let poolAsset: HydraDx.AssetId

    init(
        origin: ChainAssetId,
        destination: ChainAssetId,
        remoteSwapPair: HydraDx.RemoteSwapPair,
        poolAsset: HydraDx.AssetId,
        quoteFactory: HydraStableswapQuoteFactory
    ) {
        self.quoteFactory = quoteFactory
        self.poolAsset = poolAsset

        super.init(
            origin: origin,
            destination: destination,
            remoteSwapPair: remoteSwapPair
        )
    }
}

extension AssetsHydraStableswapExchangeEdge: AssetExchangableGraphEdge {
    var weight: Int { 1 }

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
}
