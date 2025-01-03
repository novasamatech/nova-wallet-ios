import Foundation
import BigInt
import SubstrateSdk

struct ParachainSlotLease: Decodable {
    let accountId: AccountId
    let amount: BigUInt

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        accountId = try container.decode(BytesCodable.self).wrappedValue
        amount = try container.decode(StringScaleMapper<BigUInt>.self).value
    }
}
