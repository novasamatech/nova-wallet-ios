import BigInt
import SubstrateSdk

struct EquilibriumReservedData: Decodable {
    var value: BigUInt

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(StringScaleMapper<BigUInt>.self).value
    }
}
