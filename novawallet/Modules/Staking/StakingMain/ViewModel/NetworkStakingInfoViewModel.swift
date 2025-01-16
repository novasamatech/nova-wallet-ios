import Foundation
import Foundation_iOS

struct NetworkStakingInfoViewModel {
    let totalStake: LoadableViewModelState<BalanceViewModelProtocol>?
    let minimalStake: LoadableViewModelState<BalanceViewModelProtocol>?
    let activeNominators: LoadableViewModelState<String>?
    let stakingPeriod: LoadableViewModelState<String>?
    let lockUpPeriod: LoadableViewModelState<String>?

    var hasLoadingData: Bool {
        totalStake?.isLoading == true ||
            minimalStake?.isLoading == true ||
            activeNominators?.isLoading == true ||
            stakingPeriod?.isLoading == true ||
            lockUpPeriod?.isLoading == true
    }
}

extension NetworkStakingInfoViewModel {
    static var allLoading: NetworkStakingInfoViewModel {
        .init(
            totalStake: .loading,
            minimalStake: .loading,
            activeNominators: .loading,
            stakingPeriod: .loading,
            lockUpPeriod: .loading
        )
    }
}
