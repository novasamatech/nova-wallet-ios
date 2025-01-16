import Foundation
import BigInt
import SubstrateSdk

extension AssetConversionPallet {
    static var swapExecutedEvent: EventCodingPath {
        .init(moduleName: AssetConversionPallet.name, eventName: "SwapExecuted")
    }

    struct BalancePathItem: Codable {
        let asset: AssetId
        let amount: BigUInt

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            asset = try unkeyedContainer.decode(AssetId.self)
            amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
        }
    }

    typealias BalancePath = [BalancePathItem]

    struct SwapExecutedEvent: Codable {
        let who: AccountId
        let sendTo: AccountId
        let path: BalancePath
        let amountIn: BigUInt
        let amountOut: BigUInt

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            who = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            sendTo = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            amountIn = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
            amountOut = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
            path = try unkeyedContainer.decode(BalancePath.self)
        }
    }
}
