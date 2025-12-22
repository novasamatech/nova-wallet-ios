import Foundation

struct StakingNominationPoolsStatics: StakingMainStaticViewModelProtocol {
    var canCancelUnbonding: Bool { false }

    func networkInfoTitle(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingPoolNetworkInfo()
    }
}
