import Foundation
import SubstrateSdk

enum MythosStakingPallet {
    static let name = "CollatorStaking"

    struct UserStake: Codable, Equatable {
        @StringCodable var stake: Balance
    }
}
