import Foundation

struct StakingNominationPoolsStatics: StakingMainStaticViewModelProtocol {
    func networkInfoTitle(for locale: Locale) -> String {
        R.string.localizable.stakingPoolNetworkInfo(preferredLanguages: locale.rLanguages)
    }
}
