import Foundation
import BigInt

struct RelaychainStakingRecommendation {
    let staking: SelectedStakingOption
    let restrictions: RelaychainStakingRestrictions
    let validationFactory: StakingRecommendationValidationFactoryProtocol?
}

extension RelaychainStakingRecommendation: CustomStringConvertible {
    var description: String {
        switch staking {
        case .direct:
            "Direct: \(restrictions)"
        case .pool:
            "Pool: \(restrictions)"
        }
    }
}

struct RelaychainStakingManual {
    let staking: SelectedStakingOption
    let restrictions: RelaychainStakingRestrictions
    let usedRecommendation: Bool
}
