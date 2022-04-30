import Foundation
import SubstrateSdk

struct SelectValidatorsConfirmViewModel {
    let walletViewModel: DisplayWalletViewModel
    let accountViewModel: DisplayAddressViewModel
    let rewardDestination: RewardDestinationTypeViewModel?
    let validatorsCount: Int
    let maxValidatorCount: Int
}
