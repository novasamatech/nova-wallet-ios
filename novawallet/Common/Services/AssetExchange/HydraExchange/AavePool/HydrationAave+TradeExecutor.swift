import Foundation
import SubstrateSdk

extension HydraAave {
    static var traderPairsPath: StateCallPath {
        StateCallPath(module: "AaveTradeExecutor", method: "pairs")
    }

    static var traderPoolsPath: StateCallPath {
        StateCallPath(module: "AaveTradeExecutor", method: "pools")
    }

    struct PoolData: Decodable, Equatable {
        @StringCodable var reserve: HydraDx.AssetId
        @StringCodable var atoken: HydraDx.AssetId
        @StringCodable var liqudityIn: Balance
        @StringCodable var liqudityOut: Balance
    }

    struct TradePair: Decodable {
        let asset1: HydraDx.AssetId
        let asset2: HydraDx.AssetId

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()
            asset1 = try container.decode(StringCodable.self).wrappedValue
            asset2 = try container.decode(StringCodable.self).wrappedValue
        }
    }
}

extension HydraAave.PoolData {
    func canHandleTrade(for pair: HydraDx.RemoteSwapPair) -> Bool {
        canHandleTrade(assetIn: pair.assetIn, assetOut: pair.assetOut)
    }

    func canHandleTrade(assetIn: HydraDx.AssetId, assetOut: HydraDx.AssetId) -> Bool {
        findPoolTokenLiquidity(for: assetIn) != nil &&
            findPoolTokenLiquidity(for: assetOut) != nil
    }

    func findPoolTokenLiquidity(for assetId: HydraDx.AssetId) -> Balance? {
        switch assetId {
        case reserve:
            liqudityIn
        case atoken:
            liqudityOut
        default:
            nil
        }
    }
}
