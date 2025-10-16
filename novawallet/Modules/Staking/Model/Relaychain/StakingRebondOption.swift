import Foundation

enum StakingRebondOption: CaseIterable {
    case all
    case last
    case customAmount
}

extension StakingRebondOption {
    func titleForLocale(_ locale: Locale?) -> String {
        switch self {
        case .all:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingRebondActionAll()
        case .last:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingRebondActionLast()
        case .customAmount:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingRebondActionCustom()
        }
    }
}
