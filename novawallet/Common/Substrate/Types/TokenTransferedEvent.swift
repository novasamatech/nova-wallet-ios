import Foundation
import SubstrateSdk
import BigInt

struct TokenTransferedEvent: Decodable {
    let currencyId: JSON
    let sender: AccountId
    let receiver: AccountId
    let amount: BigUInt

    init(from decoder: Decoder) throws {
        var unkeyedContainer = try decoder.unkeyedContainer()

        currencyId = try unkeyedContainer.decode(JSON.self)

        sender = try unkeyedContainer.decode(AccountIdCodingWrapper.self).wrappedValue

        receiver = try unkeyedContainer.decode(AccountIdCodingWrapper.self).wrappedValue

        amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
    }
}
