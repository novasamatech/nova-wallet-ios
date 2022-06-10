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
            return R.string.localizable.stakingRebondActionAll(preferredLanguages: locale?.rLanguages)
        case .last:
            return R.string.localizable.stakingRebondActionLast(preferredLanguages: locale?.rLanguages)
        case .customAmount:
            return R.string.localizable.stakingRebondActionCustom(preferredLanguages: locale?.rLanguages)
        }
    }
}
