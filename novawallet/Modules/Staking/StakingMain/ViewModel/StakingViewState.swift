import Foundation
import Foundation_iOS

enum StakingViewState {
    case undefined
    case nominator(
        viewModel: LocalizableResource<NominationViewModel>,
        alerts: [StakingAlert],
        reward: LocalizableResource<StakingRewardViewModel>?,
        unbondings: StakingUnbondingViewModel?,
        actions: [StakingManageOption]
    )
    case validator(
        viewModel: LocalizableResource<ValidationViewModel>,
        alerts: [StakingAlert],
        reward: LocalizableResource<StakingRewardViewModel>?,
        unbondings: StakingUnbondingViewModel?,
        actions: [StakingManageOption]
    )

    var rawType: Int {
        switch self {
        case .undefined:
            return 0
        case .nominator:
            return 1
        case .validator:
            return 2
        }
    }
}
