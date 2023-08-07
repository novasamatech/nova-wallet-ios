import Foundation

enum StakingSelectionMethod {
    case recommendation(RelaychainStakingRecommendation?)
    case manual(SelectedStakingOption, RelaychainStakingRestrictions)

    var isRecommendation: Bool {
        switch self {
        case .recommendation:
            return true
        case .manual:
            return false
        }
    }

    var selectedStakingOption: SelectedStakingOption? {
        switch self {
        case let .recommendation(recommendation):
            return recommendation?.staking
        case let .manual(staking, _):
            return staking
        }
    }

    var restrictions: RelaychainStakingRestrictions? {
        switch self {
        case let .recommendation(recommendation):
            return recommendation?.restrictions
        case let .manual(_, restrictions):
            return restrictions
        }
    }

    var recommendation: RelaychainStakingRecommendation? {
        switch self {
        case let .recommendation(recommendation):
            return recommendation
        case let .manual:
            return nil
        }
    }
}
