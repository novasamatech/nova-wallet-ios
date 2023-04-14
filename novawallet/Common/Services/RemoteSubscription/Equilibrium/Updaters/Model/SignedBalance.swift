import BigInt
import SubstrateSdk

enum SignedBalance: Codable {
    case positive(BigUInt)
    case negative(BigUInt)

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type.lowercased() {
        case "positive":
            let balance = try container.decode(StringScaleMapper<BigUInt>.self).value
            self = .positive(balance)
        case "negative":
            let balance = try container.decode(StringScaleMapper<BigUInt>.self).value
            self = .negative(balance)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected asset status"
            )
        }
    }
}
