import Foundation
import BigInt
import SubstrateSdk

enum AssetTxPaymentPallet {
    static let name = "AssetTxPayment"

    static var assetTxFeePaidEvent: EventCodingPath {
        .init(moduleName: Self.name, eventName: "AssetTxFeePaid")
    }

    struct AssetTxFeePaid: Codable {
        @StringCodable var actualFee: BigUInt
        let assetId: JSON
    }
}
