import Foundation
import BigInt

extension HydraStableswap {
    struct QuoteParams {
        let poolInfo: PoolRemoteState
        let reserves: ReservesRemoteState
    }

    struct QuoteArgs: Equatable {
        let assetIn: HydraDx.AssetId
        let assetOut: HydraDx.AssetId
        let poolAsset: HydraDx.AssetId
        let amount: BigUInt
        let direction: AssetConversion.Direction
    }
}
