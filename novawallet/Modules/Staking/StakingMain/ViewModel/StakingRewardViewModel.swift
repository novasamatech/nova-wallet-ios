import Foundation

struct StakingRewardViewModel {
    let totalRewards: LoadableViewModelState<BalanceViewModelProtocol>
    let claimableRewards: LoadableViewModelState<BalanceViewModelProtocol>?
    let filter: String?
}
