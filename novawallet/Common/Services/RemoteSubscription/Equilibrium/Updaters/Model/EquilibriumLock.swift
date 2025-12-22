import BigInt
import SubstrateSdk
import Foundation

struct EquilibriumLock: Decodable {
    let type: Data
    let amount: BigUInt

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        type = try container.decode(BytesCodable.self).wrappedValue
        amount = try container.decode(StringScaleMapper<BigUInt>.self).value
    }
}
