import Foundation

protocol StakingMainStaticViewModelProtocol {
    func networkInfoActiveNominators(for locale: Locale) -> String
    func actionsYourValidators(for locale: Locale) -> String
    func waitingNextEra(for timeString: String, locale: Locale) -> String
    func networkInfoTitle(for locale: Locale) -> String
}

extension StakingMainStaticViewModelProtocol {
    func networkInfoActiveNominators(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingMainActiveNominatorsTitle()
    }

    func actionsYourValidators(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingYourValidatorsTitle()
    }

    func waitingNextEra(for timeString: String, locale: Locale) -> String {
        R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingWaitingNextEraFormat(timeString).uppercased()
    }

    func networkInfoTitle(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingNetworkInfoTitle()
    }
}
