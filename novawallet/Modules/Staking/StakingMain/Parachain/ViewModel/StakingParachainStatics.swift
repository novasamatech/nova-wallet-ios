import Foundation

struct StakingParachainStatics: StakingMainStaticViewModelProtocol {
    func networkInfoActiveNominators(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages
        ).localizable.parachainStakingActiveDelegators()
    }

    func actionsYourValidators(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages
        ).localizable.parachainStakingYourCollator()
    }

    func waitingNextEra(for timeString: String, locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages
        ).localizable.parachainStakingWaitingNextRoundFormat(timeString)
    }
}
