import SubstrateSdk
import BigInt

struct StringContainer: Decodable {
    var value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(BytesCodable.self).wrappedValue
        value = String(data: data, encoding: .utf8) ?? ""
    }
}
