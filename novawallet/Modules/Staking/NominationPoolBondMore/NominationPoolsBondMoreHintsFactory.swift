import Foundation
import BigInt

protocol NominationPoolsBondMoreHintsFactoryProtocol {
    func createHints(
        rewards: BigUInt?,
        locale: Locale
    ) -> [String]
}

final class NominationPoolsBondMoreHintsFactory {
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

extension NominationPoolsBondMoreHintsFactory: NominationPoolsBondMoreHintsFactoryProtocol {
    func createHints(
        rewards: BigUInt?,
        locale: Locale
    ) -> [String] {
        let eraHint = R.string.localizable.stakingHintRewardBondMore(preferredLanguages: locale.rLanguages)

        var hints: [String] = [eraHint]

        if let rewards = rewards, rewards > 0 {
            let decimalAmount = rewards.decimal(precision: chainAsset.asset.precision)
            let hint = balanceViewModelFactory.amountFromValue(decimalAmount).value(for: locale)

            hints.append(hint)
        }

        return hints
    }
}
