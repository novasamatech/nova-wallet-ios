import Foundation
import CommonWallet
import SoraFoundation

struct PeriodRewardViewModel {
    let monthly: String
    let yearly: String
}

struct StakingEstimationViewModel {
    let reward: LocalizableResource<PeriodRewardViewModel>?
}
