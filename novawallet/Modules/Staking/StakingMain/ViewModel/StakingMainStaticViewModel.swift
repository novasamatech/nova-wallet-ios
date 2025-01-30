import Foundation

protocol StakingMainStaticViewModelProtocol {
    func networkInfoActiveNominators(for locale: Locale) -> String
    func actionsYourValidators(for locale: Locale) -> String
    func waitingNextEra(for timeString: String, locale: Locale) -> String
    func networkInfoTitle(for locale: Locale) -> String
}

extension StakingMainStaticViewModelProtocol {
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

    func networkInfoTitle(for locale: Locale) -> String {
        R.string.localizable.stakingNetworkInfoTitle(preferredLanguages: locale.rLanguages)
    }
}
