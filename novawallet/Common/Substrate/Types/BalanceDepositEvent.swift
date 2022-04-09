import Foundation
import SubstrateSdk
import BigInt

struct BalanceDepositEvent: Decodable {
    let accountId: AccountId
    let amount: BigUInt

    init(from decoder: Decoder) throws {
        var unkeyedContainer = try decoder.unkeyedContainer()

        if let rawAccountId = try? unkeyedContainer.decode(AccountId.self) {
            accountId = rawAccountId
        } else {
            accountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
        }

        amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
    }
}
