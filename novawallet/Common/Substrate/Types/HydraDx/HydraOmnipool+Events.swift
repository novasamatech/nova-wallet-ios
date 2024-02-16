import Foundation
import BigInt
import SubstrateSdk

extension HydraOmnipool {
    static var sellExecutedPath: EventCodingPath {
        .init(moduleName: Self.moduleName, eventName: "SellExecuted")
    }

    static var buyExecutedPath: EventCodingPath {
        .init(moduleName: Self.moduleName, eventName: "BuyExecuted")
    }

    struct SwapExecuted: Decodable {
        let reciepient: AccountId
        let assetIn: HydraDx.AssetId
        let assetOut: HydraDx.AssetId
        let amountIn: BigUInt
        let amountOut: BigUInt

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            reciepient = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            assetIn = try unkeyedContainer.decode(StringScaleMapper<HydraDx.AssetId>.self).value
            assetOut = try unkeyedContainer.decode(StringScaleMapper<HydraDx.AssetId>.self).value
            amountIn = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
            amountOut = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
        }
    }
}
