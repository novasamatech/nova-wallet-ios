import Foundation

struct StakingRewardDetailsViewModel {
    let amount: BalanceViewModelProtocol
    let validator: StackCellViewModel
    let era: StackCellViewModel
}
