import Foundation
import CommonWallet
import SoraFoundation

struct PeriodRewardViewModel {
    let monthly: String
    let yearly: String
}

struct StakingEstimationViewModel {
    let tokenSymbol: String
    let reward: LocalizableResource<PeriodRewardViewModel>?
}
