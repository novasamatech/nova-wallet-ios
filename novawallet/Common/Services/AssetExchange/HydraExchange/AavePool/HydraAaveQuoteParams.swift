import Foundation

extension HydraAave {
    // TODO: Consider using shared models
    struct QuoteArgs: Equatable {
        let assetIn: HydraDx.AssetId
        let assetOut: HydraDx.AssetId
        let amount: Balance
        let direction: AssetConversion.Direction
    }

    struct Quote: Equatable {
        let amountIn: Balance
        let assetIn: HydraDx.AssetId
        let amountOut: Balance
        let assetOut: HydraDx.AssetId
    }
}
