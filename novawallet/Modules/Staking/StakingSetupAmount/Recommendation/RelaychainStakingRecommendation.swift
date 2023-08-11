import Foundation
import BigInt

struct RelaychainStakingRecommendation {
    let staking: SelectedStakingOption
    let restrictions: RelaychainStakingRestrictions
    let validationFactory: StakingRecommendationValidationFactoryProtocol?
}

struct RelaychainStakingManual {
    let staking: SelectedStakingOption
    let restrictions: RelaychainStakingRestrictions
    let usedRecommendation: Bool
}
