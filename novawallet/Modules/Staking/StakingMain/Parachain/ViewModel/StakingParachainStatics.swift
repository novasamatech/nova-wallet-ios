import Foundation

struct StakingParachainStatics: StakingMainStaticViewModelProtocol {
    func networkInfoActiveNominators(for locale: Locale) -> String {
        R.string.localizable.parachainStakingActiveDelegators(
            preferredLanguages: locale.rLanguages
        )
    }

    func actionsYourValidators(for locale: Locale) -> String {
        R.string.localizable.parachainStakingYourCollator(
            preferredLanguages: locale.rLanguages
        )
    }

    func waitingNextEra(for timeString: String, locale: Locale) -> String {
        R.string.localizable.parachainStakingWaitingNextRoundFormat(
            timeString,
            preferredLanguages: locale.rLanguages
        )
    }
}
