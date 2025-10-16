import UIKit.UIImage

enum StakingRewardStatus {
    case claimable
    case received
}

extension StakingRewardStatus {
    func titleForLocale(_ locale: Locale?) -> String {
        switch self {
        case .claimable:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingRewardDetailsStatusClaimable()
        case .received:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingRewardDetailsStatusReceived()
        }
    }

    var icon: UIImage? {
        switch self {
        case .claimable:
            return R.image.iconPending()
        case .received:
            return R.image.iconValid()
        }
    }
}
