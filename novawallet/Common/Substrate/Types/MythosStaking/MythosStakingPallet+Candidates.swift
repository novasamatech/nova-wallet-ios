import Foundation
import SubstrateSdk

extension MythosStakingPallet {
    struct CandidateInfo: Decodable {
        @StringCodable var stake: Balance
        @StringCodable var stakers: UInt32
    }
}
