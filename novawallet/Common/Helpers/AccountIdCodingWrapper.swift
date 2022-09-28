import Foundation
import SubstrateSdk

struct AccountIdCodingWrapper: Decodable {
    let wrappedValue: AccountId

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let rawAccountId = try? container.decode(AccountId.self) {
            wrappedValue = rawAccountId
        } else {
            wrappedValue = try container.decode(BytesCodable.self).wrappedValue
        }
    }
}
