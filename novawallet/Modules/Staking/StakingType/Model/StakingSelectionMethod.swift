import Foundation

enum StakingSelectionMethod {
    case recommendation(RelaychainStakingRecommendation?)
    case manual(RelaychainStakingManual)

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
        case let .manual(manual):
            return manual.staking
        }
    }

    var restrictions: RelaychainStakingRestrictions? {
        switch self {
        case let .recommendation(recommendation):
            return recommendation?.restrictions
        case let .manual(manual):
            return manual.restrictions
        }
    }

    var recommendation: RelaychainStakingRecommendation? {
        switch self {
        case let .recommendation(recommendation):
            return recommendation
        case .manual:
            return nil
        }
    }
}
