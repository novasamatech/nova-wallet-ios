import Foundation

extension NominationPools {
    enum ClaimRewardsStrategy: String {
        case restake
        case freeBalance
    }
}

extension NominationPools.ClaimRewardsStrategy {
    func toViewMode() -> StakingClaimRewardsViewMode {
        switch self {
        case .restake:
            return .restake
        case .freeBalance:
            return .freeBalance
        }
    }
}
