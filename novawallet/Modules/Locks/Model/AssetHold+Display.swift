import Foundation

extension AssetHold {
    func displayTitle(for locale: Locale) -> String {
        switch (module, reason) {
        case ("DelegatedStaking", "StakingDelegation"):
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingTypeNominationPool()
        default:
            return "\(module): \(reason)"
        }
    }
}
