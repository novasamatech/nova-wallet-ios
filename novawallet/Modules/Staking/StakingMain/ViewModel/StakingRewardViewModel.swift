import UIKit

struct StakingRewardViewModel {
    struct ClaimableRewards {
        let balance: BalanceViewModelProtocol
        let canClaim: Bool
    }

    let totalRewards: LoadableViewModelState<BalanceViewModelProtocol>
    let claimableRewards: LoadableViewModelState<ClaimableRewards>?
    let graphics: UIImage?
    let filter: String?
    let hasPrice: Bool
}
