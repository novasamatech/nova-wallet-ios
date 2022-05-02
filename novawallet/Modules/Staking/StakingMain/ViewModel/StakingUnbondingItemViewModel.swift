import Foundation
import SoraFoundation

struct StakingUnbondingViewModel {
    let eraCountdown: EraCountdown?
    let items: [StakingUnbondingItemViewModel]
}

struct StakingUnbondingItemViewModel {
    let amount: LocalizableResource<String>
    let unbondingEra: EraIndex

    func isNext(from activeEra: EraIndex) -> Bool {
        unbondingEra == activeEra + 1
    }

    func isRedeemable(from activeEra: EraIndex) -> Bool {
        unbondingEra <= activeEra
    }
}
