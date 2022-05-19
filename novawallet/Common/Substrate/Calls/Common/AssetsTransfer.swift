import Foundation
import SubstrateSdk
import BigInt

struct AssetsTransfer: Codable {
    enum CodingKeys: String, CodingKey {
        case assetId = "id"
        case target
        case amount
    }

    let assetId: String
    let target: MultiAddress
    @StringCodable var amount: BigUInt
}
