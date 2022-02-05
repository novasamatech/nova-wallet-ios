import Foundation
import BigInt
import SubstrateSdk

struct AssetDetails: Codable {
    @StringCodable var minBalance: BigUInt
    let isFrozen: Bool
}
