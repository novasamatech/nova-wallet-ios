import Foundation
import BigInt

protocol NPoolsUnstakeHintsFactoryProtocol {
    func createHints(
        stakingDuration: StakingDuration?,
        rewards: BigUInt?,
        locale: Locale
    ) -> [String]
}

final class NPoolsUnstakeHintsFactory {
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
    }
}

extension NPoolsUnstakeHintsFactory: NPoolsUnstakeHintsFactoryProtocol {
    func createHints(
        stakingDuration: StakingDuration?,
        rewards: BigUInt?,
        locale: Locale
    ) -> [String] {
        var hints: [String] = []

        if let stakingDuration = stakingDuration {
            let duration = stakingDuration.localizableUnlockingString.value(for: locale)
            let hint = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingHintUnstakeFormat_v2_2_0(duration)

            hints.append(hint)
        }

        hints.append(contentsOf: [
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingHintNoRewards_v2_2_0(),
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingHintRedeem()
        ])

        if let rewards = rewards, rewards > 0 {
            let decimalAmount = rewards.decimal(precision: chainAsset.asset.precision)
            let amountString = balanceViewModelFactory.amountFromValue(decimalAmount).value(for: locale)
            let hint = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingPoolRewardsClaimHint(amountString)

            hints.append(hint)
        }

        return hints
    }
}
