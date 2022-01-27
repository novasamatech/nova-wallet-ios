import Foundation
import SubstrateSdk
import BigInt

struct OrmlTokenTransfer: Codable {
    enum CodingKeys: String, CodingKey {
        case dest
        case currencyId = "currency_id"
        case amount
    }

    let dest: MultiAddress
    let currencyId: JSON
    @StringCodable var amount: BigUInt
}
