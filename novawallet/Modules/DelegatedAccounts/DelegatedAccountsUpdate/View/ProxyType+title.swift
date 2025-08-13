import Foundation

extension Proxy.ProxyType {
    func title(locale: Locale) -> String {
        let typeString: String

        switch self {
        case .any:
            typeString = R.string.localizable.proxyAnyTypeTitle(
                preferredLanguages: locale.rLanguages
            )
        case .nonTransfer:
            typeString = R.string.localizable.proxyNonTransferTypeTitle(
                preferredLanguages: locale.rLanguages
            )
        case .governance:
            typeString = R.string.localizable.proxyGovernanceTypeTitle(
                preferredLanguages: locale.rLanguages
            )
        case .staking:
            typeString = R.string.localizable.proxyStakingTypeTitle(
                preferredLanguages: locale.rLanguages
            )
        case .nominationPools:
            typeString = R.string.localizable.proxyNominationPoolsTypeTitle(
                preferredLanguages: locale.rLanguages
            )
        case .identityJudgement:
            typeString = R.string.localizable.proxyIdentityTypeTitle(
                preferredLanguages: locale.rLanguages
            )
        case .cancelProxy:
            typeString = R.string.localizable.proxyCancelProxyTypeTitle(
                preferredLanguages: locale.rLanguages
            )
        case .auction:
            typeString = R.string.localizable.proxyAuctionTypeTitle(
                preferredLanguages: locale.rLanguages
            )
        case let .other(type):
            typeString = type
        }

        return R.string.localizable.proxyUpdatesOtherTypeTitle(
            typeString,
            preferredLanguages: locale.rLanguages
        )
    }

    func subtitle(locale: Locale) -> String {
        title(locale: locale) + ": "
    }
}
