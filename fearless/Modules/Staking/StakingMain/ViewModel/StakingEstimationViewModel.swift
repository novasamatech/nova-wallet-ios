import Foundation
import CommonWallet
import SoraFoundation

struct PeriodRewardViewModel {
    let monthlyReward: RewardViewModelProtocol
    let yearlyReward: RewardViewModelProtocol
}

struct APYViewModel {
    let avgAPY: RewardViewModelProtocol
    let maxAPY: RewardViewModelProtocol
}

struct StakingEstimationViewModel {
    let assetBalance: LocalizableResource<AssetBalanceViewModelProtocol>
    let rewardViewModel: LocalizableResource<APYViewModel>?
    let assetInfo: AssetBalanceDisplayInfo
    let inputLimit: Decimal
    let amount: Decimal?
}
