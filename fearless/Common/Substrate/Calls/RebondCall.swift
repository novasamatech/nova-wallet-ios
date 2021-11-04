import Foundation
import SubstrateSdk
import BigInt

struct RebondCall: Codable {
    enum CodingKeys: String, CodingKey {
        case amount = "value"
    }

    @StringCodable var amount: BigUInt
}
