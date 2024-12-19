import Foundation
import BigInt

extension HydraXYK {
    struct QuoteParams {}

    struct QuoteArgs: Equatable {
        let assetIn: HydraDx.AssetId
        let assetOut: HydraDx.AssetId
        let amount: BigUInt
        let direction: AssetConversion.Direction
    }

    struct Quote: Equatable {
        let amountIn: BigUInt
        let assetIn: HydraDx.AssetId
        let amountOut: BigUInt
        let assetOut: HydraDx.AssetId
    }
}
