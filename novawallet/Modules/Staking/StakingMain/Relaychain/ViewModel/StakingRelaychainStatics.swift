import Foundation

struct StakingRelaychainStatics: StakingMainStaticViewModelProtocol {
    func networkInfoActiveNominators(for locale: Locale) -> String {
        R.string.localizable.stakingMainActiveNominatorsTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    func actionsYourValidators(for locale: Locale) -> String {
        R.string.localizable.stakingYourValidatorsTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    func waitingNextEra(for timeString: String, locale: Locale) -> String {
        R.string.localizable.stakingWaitingNextEraFormat(
            timeString,
            preferredLanguages: locale.rLanguages
        ).uppercased()
    }
}
