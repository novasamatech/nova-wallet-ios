import Foundation
import SubstrateSdk
import BigInt

struct OrmlTokenTransfer: Codable {
    let dest: MultiAddress
    let currencyId: JSON
    @StringCodable var amount: BigUInt
}
