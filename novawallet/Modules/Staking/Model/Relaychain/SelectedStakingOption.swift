import Foundation

enum SelectedStakingOption {
    case direct([SelectedValidatorInfo])
    case pool(NominationPools.SelectedPool)
}
