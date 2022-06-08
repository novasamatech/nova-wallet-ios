import Foundation

protocol ParaStkHintsViewModelFactoryProtocol {
    func unstakeHint(for duration: ParachainStakingDuration, locale: Locale) -> String
    func unstakingRewards(for locale: Locale) -> String
    func unstakingRedeem(for locale: Locale) -> String
    func unstakingRebond(for locale: Locale) -> String
}

final class ParaStkHintsViewModelFactory: ParaStkHintsViewModelFactoryProtocol {
    func unstakeHint(for duration: ParachainStakingDuration, locale: Locale) -> String {
        let unstakingPeriod = duration.unstaking.localizedDaysHours(for: locale)

        return R.string.localizable.stakingHintUnstakeFormat_v2_2_0(
            unstakingPeriod,
            preferredLanguages: locale.rLanguages
        )
    }

    func unstakingRewards(for locale: Locale) -> String {
        R.string.localizable.stakingHintNoRewards_V2_2_0(preferredLanguages: locale.rLanguages)
    }

    func unstakingRedeem(for locale: Locale) -> String {
        R.string.localizable.stakingHintRedeem_v2_2_0(preferredLanguages: locale.rLanguages)
    }

    func unstakingRebond(for locale: Locale) -> String {
        R.string.localizable.parastkRebondHint(preferredLanguages: locale.rLanguages)
    }
}
