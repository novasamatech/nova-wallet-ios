import Foundation
import SubstrateSdk

enum MythosStakingPallet {
    static let name = "CollatorStaking"

    struct UserStake: Codable {
        @StringCodable var stake: Balance
    }
}
