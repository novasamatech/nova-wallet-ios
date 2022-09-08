import Foundation
import BigInt

struct ParaStkYieldBoostRequest: Encodable {
    enum CodingKeys: String, CodingKey {
        case amountToStake = "principal"
        case collator
    }

    let amountToStake: Decimal
    let collator: AccountAddress
}

struct ParaStkYieldBoostResponse: Decodable {
    let apy: Decimal
    let period: UInt
}
