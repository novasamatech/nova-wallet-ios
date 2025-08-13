import Foundation
import SubstrateSdk
import BigInt

struct AccountInfo: Codable, Equatable {
    @StringCodable var nonce: UInt32
    @OptionStringCodable var consumers: UInt32?
    @OptionStringCodable var providers: UInt32?
    let data: AccountData

    var hasConsumers: Bool {
        (consumers ?? 0) > 0
    }

    var hasProviders: Bool {
        (providers ?? 0) > 0
    }
}

struct AccountData: Codable, Equatable {
    @StringCodable var free: BigUInt
    @StringCodable var reserved: BigUInt
    @OptionStringCodable var frozen: BigUInt?
    @OptionStringCodable var miscFrozen: BigUInt?
    @OptionStringCodable var feeFrozen: BigUInt?
    @OptionStringCodable var flags: BigUInt?
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

extension AccountData {
    static let fungibleTraitLogic = BigUInt(1) << 127

    var isFungibleTraitLogic: Bool {
        guard let flags = flags else {
            return false
        }

        return (flags & Self.fungibleTraitLogic) == Self.fungibleTraitLogic
    }

    var edCountMode: AssetBalance.ExistentialDepositCountMode {
        isFungibleTraitLogic ? .basedOnFree : .basedOnTotal
    }

    var transferrableModel: AssetBalance.TransferrableMode {
        isFungibleTraitLogic ? .fungibleTrait : .regular
    }
}
