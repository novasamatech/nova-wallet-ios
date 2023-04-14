import BigInt
import SubstrateSdk

struct EquilibriumLock: Decodable {
    var type: Data
    var amount: BigUInt

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        type = try container.decode(BytesCodable.self).wrappedValue
        amount = try container.decode(StringScaleMapper<BigUInt>.self).value
    }
}
