import Foundation
import BigInt
import SubstrateSdk

struct AssetAccount: Codable {
    @StringCodable var balance: BigUInt
    let isFrozen: Bool
}
