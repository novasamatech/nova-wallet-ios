import Foundation

extension Proxy.ProxyType {
    func title(locale: Locale) -> String {
        switch self {
        case .any:
            return R.string.localizable.proxyUpdatesAnyTypeTitle(
                preferredLanguages: locale.rLanguages
            )
        case .nonTransfer:
            return R.string.localizable.proxyUpdatesNonTransferTypeTitle(
                preferredLanguages: locale.rLanguages
            )
        case .governance:
            return R.string.localizable.proxyUpdatesGovernanceTypeTitle(
                preferredLanguages: locale.rLanguages
            )
        case .staking:
            return R.string.localizable.proxyUpdatesStakingTypeTitle(
                preferredLanguages: locale.rLanguages
            )
        case let .other(type):
            return R.string.localizable.proxyUpdatesOtherTypeTitle(
                type,
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func subtitle(locale: Locale) -> String {
        title(locale: locale) + ": "
    }
}
