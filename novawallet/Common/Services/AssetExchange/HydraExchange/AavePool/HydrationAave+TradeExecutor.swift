import Foundation
import SubstrateSdk

extension HydraAave {
    static var traderPairsPath: StateCallPath {
        StateCallPath(module: "AaveTradeExecutor", method: "pairs")
    }

    static var traderPoolsPath: StateCallPath {
        StateCallPath(module: "AaveTradeExecutor", method: "pools")
    }

    static var traderPoolPath: StateCallPath {
        StateCallPath(module: "AaveTradeExecutor", method: "pool")
    }

    struct PoolData: Decodable, Equatable {
        @StringCodable var reserve: HydraDx.AssetId
        @StringCodable var atoken: HydraDx.AssetId
        @StringCodable var liqudityIn: Balance
        @StringCodable var liqudityOut: Balance
    }

    struct TradePair: Decodable, Hashable {
        let asset1: HydraDx.AssetId
        let asset2: HydraDx.AssetId

        init(asset1: HydraDx.AssetId, asset2: HydraDx.AssetId) {
            self.asset1 = asset1
            self.asset2 = asset2
        }

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()
            asset1 = try container.decode(StringCodable.self).wrappedValue
            asset2 = try container.decode(StringCodable.self).wrappedValue
        }
    }

    enum PoolsSource {
        case aggregate
        case individual
    }

    struct PoolsFetchResult {
        let pools: [PoolData]
        let source: PoolsSource
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
