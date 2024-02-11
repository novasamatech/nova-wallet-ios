import Foundation
import SubstrateSdk
import BigInt

extension HydraRouter {
    struct SellCall: Codable {
        @StringCodable var assetIn: HydraDx.AssetId
        @StringCodable var assetOut: HydraDx.AssetId
        @StringCodable var amountIn: BigUInt
        @StringCodable var minAmountOut: BigUInt
        let route: [HydraRouter.Trade]
    }
}
