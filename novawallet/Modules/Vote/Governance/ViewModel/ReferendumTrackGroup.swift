import Foundation

enum ReferendumTrackGroup {
    case treasury
    case governance
    case fellowship

    var trackTypes: [ReferendumTrackType] {
        switch self {
        case .treasury:
            return [.bigSpender, .bigTipper, .mediumSpender, .smallSpender, .smallTipper, .treasurer]
        case .fellowship:
            return [.fellowshipAdmin, .whiteListedCaller]
        case .governance:
            return [.referendumKiller, .referendumCanceller, .leaseAdmin, .generalAdmin]
        }
    }

    static func groupsByPriority() -> [ReferendumTrackGroup] {
        [.treasury, governance, .fellowship]
    }

    func title(for locale: Locale) -> String {
        switch self {
        case .treasury:
            return R.string.localizable.govTrackGroupTreasury(preferredLanguages: locale.rLanguages)
        case .fellowship:
            return R.string.localizable.govTrackGroupFellowship(preferredLanguages: locale.rLanguages)
        case .governance:
            return R.string.localizable.govTrackGroupGovernance(preferredLanguages: locale.rLanguages)
        }
    }
}
