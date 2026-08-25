import Foundation

struct StakingSubtensorStatics: StakingMainStaticViewModelProtocol {
    func actionsYourValidators(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingYourValidatorsTitle()
    }
}
