import Foundation
import Foundation_iOS

struct StakingUnbondingViewModel {
    let eraCountdown: EraCountdownDisplayProtocol?
    let items: [StakingUnbondingItemViewModel]
    let canCancelUnbonding: Bool
}

struct StakingUnbondingItemViewModel {
    let amount: LocalizableResource<String>
    let unbondingEra: Staking.EraIndex

    func isNext(from activeEra: Staking.EraIndex) -> Bool {
        unbondingEra == activeEra + 1
    }

    func isRedeemable(from activeEra: Staking.EraIndex) -> Bool {
        unbondingEra <= activeEra
    }
}
