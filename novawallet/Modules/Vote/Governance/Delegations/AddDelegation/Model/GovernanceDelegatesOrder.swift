import Foundation

enum GovernanceDelegatesOrder: Equatable {
    case delegations
    case delegatedVotes
    case lastVoted(days: Int)
}

extension GovernanceDelegatesOrder {
    static func title(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.delegationsSortTitle()
    }

    func value(for locale: Locale) -> String {
        switch self {
        case .delegations:
            return R.string(preferredLanguages: locale.rLanguages).localizable.delegationsSortDelegations()
        case .delegatedVotes:
            return R.string(preferredLanguages: locale.rLanguages).localizable.delegationsSortDelegatedVotes()
        case let .lastVoted(days):
            let formattedDays = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonDaysFormat(format: days)
            return R.string(preferredLanguages: locale.rLanguages).localizable.delegationsSortLastVoted(formattedDays)
        }
    }
}

extension GovernanceDelegatesOrder {
    func isSame(_ delegate1: GovernanceDelegateLocal, delegate2: GovernanceDelegateLocal) -> Bool {
        switch self {
        case .delegatedVotes:
            return delegate1.stats.delegatedVotes == delegate2.stats.delegatedVotes
        case .delegations:
            return delegate1.stats.delegationsCount == delegate2.stats.delegationsCount
        case .lastVoted:
            return delegate1.stats.recentVotes == delegate2.stats.recentVotes
        }
    }

    func isDescending(_ delegate1: GovernanceDelegateLocal, delegate2: GovernanceDelegateLocal) -> Bool {
        switch self {
        case .delegatedVotes:
            return delegate1.stats.delegatedVotes > delegate2.stats.delegatedVotes
        case .delegations:
            return delegate1.stats.delegationsCount > delegate2.stats.delegationsCount
        case .lastVoted:
            return delegate1.stats.recentVotes > delegate2.stats.recentVotes
        }
    }
}
