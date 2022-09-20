import Foundation
import SubstrateSdk
import BigInt

struct BalancesTransferEvent: Decodable {
    let sender: AccountId
    let receiver: AccountId
    let amount: BigUInt

    init(from decoder: Decoder) throws {
        var unkeyedContainer = try decoder.unkeyedContainer()

        sender = try unkeyedContainer.decode(AccountIdCodingWrapper.self).wrappedValue

        receiver = try unkeyedContainer.decode(AccountIdCodingWrapper.self).wrappedValue

        amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
    }
}
