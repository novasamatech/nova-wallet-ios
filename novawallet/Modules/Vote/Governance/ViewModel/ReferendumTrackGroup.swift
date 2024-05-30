import Foundation

enum ReferendumTrackGroup {
    case treasury
    case governance
    case fellowship

    var trackTypes: [String] {
        switch self {
        case .treasury:
            return [
                ReferendumTrackType.bigSpender,
                ReferendumTrackType.bigTipper,
                ReferendumTrackType.mediumSpender,
                ReferendumTrackType.smallSpender,
                ReferendumTrackType.smallTipper,
                ReferendumTrackType.treasurer
            ]
        case .fellowship:
            return [
                ReferendumTrackType.fellowshipAdmin,
                ReferendumTrackType.whiteListedCaller
            ]
        case .governance:
            return [
                ReferendumTrackType.referendumKiller,
                ReferendumTrackType.referendumCanceller,
                ReferendumTrackType.leaseAdmin,
                ReferendumTrackType.generalAdmin
            ]
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
