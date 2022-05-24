import Foundation
import SubstrateSdk
import BigInt

struct BondExtraCall: Codable {
    enum CodingKeys: String, CodingKey {
        case amount = "max_additional"
    }

    @StringCodable var amount: BigUInt
}
