import Foundation

enum DelegatesSortOption {
    case delegations
    case delegatedVotes
    case lastVoted(days: Int)
}

extension DelegatesSortOption {
    func title(for locale: Locale) -> String {
        R.string.localizable.delegationsSortTitle(preferredLanguages: locale.rLanguages) + ":"
    }

    static func title(for locale: Locale) -> String {
        R.string.localizable.delegationsSortTitle(preferredLanguages: locale.rLanguages)
    }

    func value(for locale: Locale) -> String {
        switch self {
        case .delegations:
            return R.string.localizable.delegationsSortDelegations(preferredLanguages: locale.rLanguages)
        case .delegatedVotes:
            return R.string.localizable.delegationsSortDelegatedVotes(preferredLanguages: locale.rLanguages)
        case let .lastVoted(days):
            let formattedDays = R.string.localizable.commonDaysFormat(format: days, preferredLanguages: locale.rLanguages)
            return R.string.localizable.delegationsSortLastVoted(formattedDays, preferredLanguages: locale.rLanguages)
        }
    }
}
