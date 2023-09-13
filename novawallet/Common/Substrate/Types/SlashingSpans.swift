import Foundation
import SubstrateSdk

struct SlashingSpans: Decodable {
    @StringCodable var lastNonzeroSlash: UInt32
    let prior: [StringScaleMapper<UInt32>]
}

extension SlashingSpans {
    var numOfSlashingSpans: UInt32 {
        UInt32(prior.count) + 1
    }
}
