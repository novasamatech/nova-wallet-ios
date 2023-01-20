import Foundation

enum DelegatesShowOption: CaseIterable {
    case individuals
    case organizations
    case all
}

extension DelegatesShowOption {
    func title(for locale: Locale) -> String {
        R.string.localizable.delegationsShowTitle(preferredLanguages: locale.rLanguages) + ":"
    }

    static func title(for locale: Locale) -> String {
        R.string.localizable.delegationsShowTitle(preferredLanguages: locale.rLanguages)
    }

    func value(for locale: Locale) -> String {
        switch self {
        case .individuals:
            return R.string.localizable.delegationsShowIndividuals(preferredLanguages: locale.rLanguages)
        case .organizations:
            return R.string.localizable.delegationsShowOrganizations(preferredLanguages: locale.rLanguages)
        case .all:
            return R.string.localizable.delegationsShowAll(preferredLanguages: locale.rLanguages)
        }
    }
}
