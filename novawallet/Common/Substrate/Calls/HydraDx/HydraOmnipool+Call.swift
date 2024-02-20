import Foundation
import SubstrateSdk
import BigInt

extension HydraOmnipool {
    static func isSwap(callPath: CallCodingPath) -> Bool {
        callPath == SellCall.callPath || callPath == BuyCall.callPath
    }

    struct SellCall: Codable {
        enum CodingKeys: String, CodingKey {
            case assetIn = "asset_in"
            case assetOut = "asset_out"
            case amount
            case minBuyAmount = "min_buy_amount"
        }

        @StringCodable var assetIn: HydraDx.AssetId
        @StringCodable var assetOut: HydraDx.AssetId
        @StringCodable var amount: BigUInt
        @StringCodable var minBuyAmount: BigUInt

        static var callPath: CallCodingPath {
            .init(moduleName: HydraOmnipool.moduleName, callName: "sell")
        }

        func runtimeCall() -> RuntimeCall<Self> {
            .init(
                moduleName: Self.callPath.moduleName,
                callName: Self.callPath.callName,
                args: self
            )
        }
    }

    struct BuyCall: Codable {
        enum CodingKeys: String, CodingKey {
            case assetOut = "asset_out"
            case assetIn = "asset_in"
            case amount
            case maxSellAmount = "max_sell_amount"
        }

        @StringCodable var assetOut: HydraDx.AssetId
        @StringCodable var assetIn: HydraDx.AssetId
        @StringCodable var amount: BigUInt
        @StringCodable var maxSellAmount: BigUInt

        static var callPath: CallCodingPath {
            .init(moduleName: HydraOmnipool.moduleName, callName: "buy")
        }

        func runtimeCall() -> RuntimeCall<Self> {
            .init(
                moduleName: Self.callPath.moduleName,
                callName: Self.callPath.callName,
                args: self
            )
        }
    }
}
