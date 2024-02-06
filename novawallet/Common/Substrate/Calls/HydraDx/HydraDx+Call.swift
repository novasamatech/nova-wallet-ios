import Foundation
import SubstrateSdk
import BigInt

extension HydraDx {
    struct SellCall: Codable {
        enum CodingKeys: String, CodingKey {
            case assetIn = "asset_in"
            case assetOut = "asset_out"
            case amount
            case minBuyAmount = "min_buy_amount"
        }

        @StringCodable var assetIn: HydraDx.OmniPoolAssetId
        @StringCodable var assetOut: HydraDx.OmniPoolAssetId
        @StringCodable var amount: BigUInt
        @StringCodable var minBuyAmount: BigUInt

        static var callPath: CallCodingPath {
            .init(moduleName: HydraDx.omniPoolModule, callName: "sell")
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

        @StringCodable var assetOut: HydraDx.OmniPoolAssetId
        @StringCodable var assetIn: HydraDx.OmniPoolAssetId
        @StringCodable var amount: BigUInt
        @StringCodable var maxSellAmount: BigUInt

        static var callPath: CallCodingPath {
            .init(moduleName: HydraDx.omniPoolModule, callName: "buy")
        }

        func runtimeCall() -> RuntimeCall<Self> {
            .init(
                moduleName: Self.callPath.moduleName,
                callName: Self.callPath.callName,
                args: self
            )
        }
    }

    struct SetCurrencyCall: Codable {
        @StringCodable var currency: HydraDx.OmniPoolAssetId

        func runtimeCall() -> RuntimeCall<Self> {
            .init(moduleName: HydraDx.multiTxPaymentModule, callName: "set_currency", args: self)
        }
    }

    struct LinkReferralCodeCall: Codable {
        @BytesCodable var code: Data

        func runtimeCall() -> RuntimeCall<Self> {
            .init(moduleName: HydraDx.referralsModule, callName: "link_code", args: self)
        }
    }
}
