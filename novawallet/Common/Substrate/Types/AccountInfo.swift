import Foundation
import SubstrateSdk
import BigInt

struct AccountInfo: Codable, Equatable {
    @StringCodable var nonce: UInt32
    let data: AccountData
}

struct AccountData: Codable, Equatable {
    @StringCodable var free: BigUInt
    @StringCodable var reserved: BigUInt
    @OptionStringCodable var frozen: BigUInt?
    @OptionStringCodable var miscFrozen: BigUInt?
    @OptionStringCodable var feeFrozen: BigUInt?
}

extension AccountData {
    var total: BigUInt { free + reserved }

    var locked: BigUInt {
        if let feeFrozen = feeFrozen, let miscFrozen = miscFrozen {
            return max(miscFrozen, feeFrozen)
        } else {
            return frozen ?? 0
        }
    }

    var available: BigUInt { free > locked ? free - locked : 0 }
}
