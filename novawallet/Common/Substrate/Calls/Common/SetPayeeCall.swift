import Foundation
import SubstrateSdk

struct SetPayeeCall: Codable {
    let payee: Staking.RewardDestinationArg
}
