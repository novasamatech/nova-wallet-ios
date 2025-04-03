import Foundation
import Foundation_iOS

struct StakingUnbondingViewModel {
    let eraCountdown: EraCountdownDisplayProtocol?
    let items: [StakingUnbondingItemViewModel]
    let canCancelUnbonding: Bool

    init(
        eraCountdown: EraCountdownDisplayProtocol?,
        items: [StakingUnbondingItemViewModel],
        canCancelUnbonding: Bool
    ) {
        self.eraCountdown = eraCountdown
        self.items = items
        self.canCancelUnbonding = canCancelUnbonding
    }
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
