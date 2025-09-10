import Foundation

enum GovernanceDelegatesFilter {
    case individuals
    case organizations
    case all
}

extension GovernanceDelegatesFilter {
    static func title(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.delegationsShowTitle()
    }

    func value(for locale: Locale) -> String {
        switch self {
        case .individuals:
            return R.string(preferredLanguages: locale.rLanguages).localizable.delegationsShowIndividuals()
        case .organizations:
            return R.string(preferredLanguages: locale.rLanguages).localizable.delegationsShowOrganizations()
        case .all:
            return R.string(preferredLanguages: locale.rLanguages).localizable.delegationsShowAll()
        }
    }
}

extension GovernanceDelegatesFilter {
    func matchesDelegate(_ delegate: GovernanceDelegateLocal) -> Bool {
        switch self {
        case .all:
            return true
        case .organizations:
            return delegate.metadata?.isOrganization == true
        case .individuals:
            return delegate.metadata?.isOrganization == false
        }
    }
}
