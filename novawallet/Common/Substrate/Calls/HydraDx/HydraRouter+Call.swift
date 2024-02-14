import Foundation
import SubstrateSdk
import BigInt

extension HydraRouter {
    static func isSwap(_ callPath: CallCodingPath) -> Bool {
        callPath == SellCall.callPath || callPath == BuyCall.callPath
    }

    struct SellCall: Codable {
        enum CodingKeys: String, CodingKey {
            case assetIn = "asset_in"
            case assetOut = "asset_out"
            case amountIn = "amount_in"
            case minAmountOut = "min_amount_out"
            case route
        }

        @StringCodable var assetIn: HydraDx.AssetId
        @StringCodable var assetOut: HydraDx.AssetId
        @StringCodable var amountIn: BigUInt
        @StringCodable var minAmountOut: BigUInt
        let route: [HydraRouter.Trade]

        static var callPath: CallCodingPath {
            .init(moduleName: HydraRouter.moduleName, callName: "sell")
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
            case assetIn = "asset_in"
            case assetOut = "asset_out"
            case amountOut = "amount_out"
            case maxAmountIn = "max_amount_in"
            case route
        }

        @StringCodable var assetIn: HydraDx.AssetId
        @StringCodable var assetOut: HydraDx.AssetId
        @StringCodable var amountOut: BigUInt
        @StringCodable var maxAmountIn: BigUInt
        let route: [HydraRouter.Trade]

        static var callPath: CallCodingPath {
            .init(moduleName: HydraRouter.moduleName, callName: "buy")
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
