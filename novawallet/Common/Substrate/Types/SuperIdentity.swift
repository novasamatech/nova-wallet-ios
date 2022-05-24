import Foundation
import SubstrateSdk

struct SuperIdentity: Codable {
    let parentAccountId: AccountId
    let data: ChainData

    var name: String? {
        if case let .raw(value) = data {
            return String(data: value, encoding: .utf8)
        } else {
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        if let accountId = try? container.decode(Data.self) {
            parentAccountId = accountId
        } else {
            parentAccountId = try container.decode(BytesCodable.self).wrappedValue
        }

        data = try container.decode(ChainData.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(parentAccountId)
        try container.encode(data)
    }
}
