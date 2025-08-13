import Foundation
import SubstrateSdk

extension Staking {
    struct SlashingSpans: Decodable {
        @StringCodable var lastNonzeroSlash: UInt32
        let prior: [StringScaleMapper<UInt32>]
    }

    struct UnappliedSlash: Decodable {
        @BytesCodable var validator: AccountId
    }

    struct UnappliedSlashKey: Decodable {}
}

extension Staking.SlashingSpans {
    var numOfSlashingSpans: UInt32 {
        UInt32(prior.count) + 1
    }
}
