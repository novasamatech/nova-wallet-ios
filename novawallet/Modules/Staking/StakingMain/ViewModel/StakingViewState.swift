import Foundation
import SoraFoundation

enum StakingViewState {
    case undefined
    case nominator(
        viewModel: LocalizableResource<NominationViewModelProtocol>,
        alerts: [StakingAlert],
        reward: LocalizableResource<StakingRewardViewModel>,
        analyticsViewModel: LocalizableResource<RewardAnalyticsWidgetViewModel>?
    )
    case validator(
        viewModel: LocalizableResource<ValidationViewModelProtocol>,
        alerts: [StakingAlert],
        reward: LocalizableResource<StakingRewardViewModel>,
        analyticsViewModel: LocalizableResource<RewardAnalyticsWidgetViewModel>?
    )
    case noStash(viewModel: StakingEstimationViewModel, alerts: [StakingAlert])
}
