import Foundation

protocol CollatorStakingHintsViewModelFactoryProtocol {
    func unstakeHint(for duration: TimeInterval, locale: Locale) -> String
    func unstakingRewards(for locale: Locale) -> String
    func unstakingRedeem(for locale: Locale) -> String
    func unstakingRebond(for locale: Locale) -> String
}

final class CollatorStakingHintsViewModelFactory: CollatorStakingHintsViewModelFactoryProtocol {
    func unstakeHint(for duration: TimeInterval, locale: Locale) -> String {
        let unstakingPeriod = duration.localizedDaysHoursOrFallbackMinutes(for: locale)

        return R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingHintUnstakeFormat_v2_2_0(
            unstakingPeriod.approximately()
        )
    }

    func unstakingRewards(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingHintNoRewards_v2_2_0()
    }

    func unstakingRedeem(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingHintRedeem_v2_2_0()
    }

    func unstakingRebond(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.parastkRebondHint()
    }
}
