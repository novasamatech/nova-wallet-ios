import Foundation

enum HydraExchange {
    struct QuoteArgs: Equatable {
        let assetIn: HydraDx.AssetId
        let assetOut: HydraDx.AssetId
        let amount: Balance
        let direction: AssetConversion.Direction
    }
}
