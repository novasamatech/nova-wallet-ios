import Foundation
import BigInt
import SubstrateSdk

extension AssetConversionPallet {
    static var swapExecutedEvent: EventCodingPath {
        .init(moduleName: AssetConversionPallet.name, eventName: "SwapExecuted")
    }

    struct SwapExecutedEvent: Codable {
        @BytesCodable var who: AccountId
        @BytesCodable var sendTo: AccountId
        let path: [AssetId]
        @StringCodable var amountIn: BigUInt
        @StringCodable var amountOut: BigUInt
    }
}
