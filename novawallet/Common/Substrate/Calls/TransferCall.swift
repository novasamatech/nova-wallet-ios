import Foundation
import SubstrateSdk
import BigInt

struct TransferCall: Codable {
    let dest: MultiAddress
    @StringCodable var value: BigUInt
}
