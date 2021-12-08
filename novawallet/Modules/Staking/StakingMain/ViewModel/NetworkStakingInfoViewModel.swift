import Foundation
import SoraFoundation

struct NetworkStakingInfoViewModel {
    let totalStake: BalanceViewModelProtocol?
    let minimalStake: BalanceViewModelProtocol?
    let activeNominators: String?
    let stakingPeriod: String?
    let lockUpPeriod: String?
}
