import Foundation

struct StakingRewardViewModel {
    struct ClaimableRewards {
        let balance: BalanceViewModelProtocol
        let canClaim: Bool
    }

    let totalRewards: LoadableViewModelState<BalanceViewModelProtocol>
    let claimableRewards: LoadableViewModelState<ClaimableRewards>?
    let filter: String?
    let hasPrice: Bool
}
