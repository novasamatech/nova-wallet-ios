import Foundation
import SoraFoundation

enum StakingViewState {
    case undefined
    case nominator(
        viewModel: LocalizableResource<NominationViewModel>,
        alerts: [StakingAlert],
        reward: LocalizableResource<StakingRewardViewModel>?,
        analyticsViewModel: LocalizableResource<RewardAnalyticsWidgetViewModel>?,
        unbondings: StakingUnbondingViewModel?,
        actions: [StakingManageOption]
    )
    case validator(
        viewModel: LocalizableResource<ValidationViewModel>,
        alerts: [StakingAlert],
        reward: LocalizableResource<StakingRewardViewModel>?,
        analyticsViewModel: LocalizableResource<RewardAnalyticsWidgetViewModel>?,
        unbondings: StakingUnbondingViewModel?,
        actions: [StakingManageOption]
    )
    case noStash(
        viewModel: StakingEstimationViewModel,
        alerts: [StakingAlert]
    )

    var rawType: Int {
        switch self {
        case .undefined:
            return 0
        case .nominator:
            return 1
        case .validator:
            return 2
        case .noStash:
            return 3
        }
    }
}
