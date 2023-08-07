import Foundation
import BigInt

struct RelaychainStakingRecommendation {
    let staking: SelectedStakingOption
    let restrictions: RelaychainStakingRestrictions
    let validationFactory: StakingRecommendationValidationFactoryProtocol?
}
