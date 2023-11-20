import Foundation
import BigInt
import SubstrateSdk

enum AssetTxPaymentPallet {
    static let name = "AssetTxPayment"

    static var assetTxFeePaidEvent: EventCodingPath {
        .init(moduleName: Self.name, eventName: "AssetTxFeePaid")
    }

    struct AssetTxFeePaid: Codable {
        let who: AccountId
        let tip: BigUInt
        let actualFee: BigUInt
        let assetId: JSON

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            who = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            actualFee = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
            tip = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
            assetId = try unkeyedContainer.decode(JSON.self)
        }
    }
}
