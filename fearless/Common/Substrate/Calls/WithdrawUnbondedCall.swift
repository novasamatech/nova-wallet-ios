import Foundation
import SubstrateSdk

struct WithdrawUnbondedCall: Codable {
    enum CodingKeys: String, CodingKey {
        case numberOfSlashingSpans = "num_slashing_spans"
    }

    @StringCodable var numberOfSlashingSpans: UInt32
}
