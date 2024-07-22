import Foundation

extension AssetHold {
    func displayTitle(for locale: Locale) -> String {
        switch (module, reason) {
        case ("DelegatedStaking", "StakingDelegation"):
            return R.string.localizable.stakingTypeNominationPool(preferredLanguages: locale.rLanguages)
        default:
            return "\(module): \(reason)"
        }
    }
}
