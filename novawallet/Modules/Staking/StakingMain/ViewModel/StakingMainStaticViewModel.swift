import Foundation

protocol StakingMainStaticViewModelProtocol {
    func networkInfoActiveNominators(for locale: Locale) -> String
    func actionsYourValidators(for locale: Locale) -> String
    func waitingNextEra(for timeString: String, locale: Locale) -> String
}
