import Foundation
import BigInt

extension HydraStableswap {
    struct QuoteParams {
        let poolInfo: PoolRemoteState
        let reserves: ReservesRemoteState
        let balances: [HydraDx.AssetId: HydraBalance]
        let assetMetadata: [HydraDx.AssetId: HydraAssetRegistry.Asset]

        func getReserve(for assetId: HydraDx.AssetId) -> Balance? {
            balances[assetId]?.free
        }

        func getDecimals(for assetId: HydraDx.AssetId) -> UInt8? {
            assetMetadata[assetId]?.decimals
        }
    }

    struct QuoteArgs: Equatable {
        let assetIn: HydraDx.AssetId
        let assetOut: HydraDx.AssetId
        let poolAsset: HydraDx.AssetId
        let amount: BigUInt
        let direction: AssetConversion.Direction
    }
}
