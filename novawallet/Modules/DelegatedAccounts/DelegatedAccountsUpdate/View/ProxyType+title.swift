import Foundation

extension Proxy.ProxyType {
    func title(locale: Locale) -> String {
        let typeString: String

        switch self {
        case .any:
            typeString = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.proxyAnyTypeTitle()
        case .nonTransfer:
            typeString = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.proxyNonTransferTypeTitle()
        case .governance:
            typeString = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.proxyGovernanceTypeTitle()
        case .staking:
            typeString = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.proxyStakingTypeTitle()
        case .nominationPools:
            typeString = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.proxyNominationPoolsTypeTitle()
        case .identityJudgement:
            typeString = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.proxyIdentityTypeTitle()
        case .cancelProxy:
            typeString = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.proxyCancelProxyTypeTitle()
        case .auction:
            typeString = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.proxyAuctionTypeTitle()
        case let .other(type):
            typeString = type
        }

        return R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.proxyUpdatesOtherTypeTitle(
            typeString
        )
    }

    func subtitle(locale: Locale) -> String {
        title(locale: locale) + ": "
    }
}
