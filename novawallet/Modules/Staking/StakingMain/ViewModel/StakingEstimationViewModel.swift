import Foundation

import Foundation_iOS

struct PeriodRewardViewModel {
    let monthly: String
    let yearly: String
}

struct StakingEstimationViewModel {
    let tokenSymbol: String
    let reward: LocalizableResource<PeriodRewardViewModel>?
}
