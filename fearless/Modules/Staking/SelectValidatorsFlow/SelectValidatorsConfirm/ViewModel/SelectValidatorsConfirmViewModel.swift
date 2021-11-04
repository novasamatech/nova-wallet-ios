import Foundation
import SubstrateSdk

struct SelectValidatorsConfirmViewModel {
    let senderIcon: DrawableIcon
    let senderName: String
    let amount: String
    let rewardDestination: RewardDestinationTypeViewModel
    let validatorsCount: Int
    let maxValidatorCount: Int
}
