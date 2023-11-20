import Foundation
import BigInt
import SubstrateSdk

extension AssetConversionPallet {
    static var swapExecutedEvent: EventCodingPath {
        .init(moduleName: AssetConversionPallet.name, eventName: "SwapExecuted")
    }

    struct SwapExecutedEvent: Codable {
        let who: AccountId
        let sendTo: AccountId
        let path: [AssetId]
        let amountIn: BigUInt
        let amountOut: BigUInt

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            who = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            sendTo = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            path = try unkeyedContainer.decode([AssetId].self)
            amountIn = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
            amountOut = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
        }
    }
}
