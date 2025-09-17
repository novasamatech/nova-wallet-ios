import Foundation

struct StakingDashboardEnabledViewModel {
    enum Status {
        case active
        case inactive
        case waiting

        init(dashboardItem: Multistaking.DashboardItem) {
            guard dashboardItem.stake != nil else {
                self = .inactive
                return
            }

            switch dashboardItem.state {
            case .active:
                self = .active
            case .waiting:
                self = .waiting
            case .inactive, .none:
                self = .inactive
            }
        }
    }

    let networkViewModel: LoadableViewModelState<NetworkViewModel>
    let totalRewards: LoadableViewModelState<SecuredViewModel<BalanceViewModelProtocol>>
    let status: LoadableViewModelState<Status>
    let yourStake: LoadableViewModelState<SecuredViewModel<BalanceViewModelProtocol>>
    let estimatedEarnings: LoadableViewModelState<String?>
    let stakingType: TitleIconViewModel?
}

struct StakingDashboardDisabledViewModel {
    let networkViewModel: LoadableViewModelState<NetworkViewModel>
    let estimatedEarnings: LoadableViewModelState<String?>
    let balance: SecuredViewModel<BalanceViewModelProtocol>?
    let stakingType: TitleIconViewModel?
}

struct StakingDashboardViewModel {
    let active: [StakingDashboardEnabledViewModel]
    let inactive: [StakingDashboardDisabledViewModel]
    let hasMoreOptions: Bool
    let isLoading: Bool
    let isSyncing: Bool

    func applyingUpdate(viewModel: StakingDashboardUpdateViewModel) -> StakingDashboardViewModel {
        var newActive = active

        viewModel.active.forEach { item in
            newActive[item.0] = item.1
        }

        var newInactive = inactive

        viewModel.inactive.forEach { item in
            newInactive[item.0] = item.1
        }

        return .init(
            active: newActive,
            inactive: newInactive,
            hasMoreOptions: hasMoreOptions,
            isLoading: isLoading,
            isSyncing: isSyncing
        )
    }
}

struct StakingDashboardUpdateViewModel {
    let active: [(Int, StakingDashboardEnabledViewModel)]
    let inactive: [(Int, StakingDashboardDisabledViewModel)]
    let isSyncing: Bool
}
