import Foundation
import SubstrateSdk

enum MythosStakingPallet {
    static let name = "CollatorStaking"

    struct UserStake: Codable, Equatable {
        @StringCodable var stake: Balance
        let candidates: [BytesCodable]
    }

    struct CandidateStakeInfo: Codable, Equatable {
        @StringCodable var stake: Balance
    }
}
