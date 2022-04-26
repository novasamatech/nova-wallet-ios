import UIKit.UIImage

enum StakingManageOption {
    case stakeMore
    case unstake
    case pendingRewards
    case rewardDestination
    case setupValidators
    case changeValidators(count: Int?)
    case controllerAccount
    case yourValidator

    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .stakeMore:
            return R.string.localizable.stakingBondMore_v190(preferredLanguages: locale.rLanguages)
        case .unstake:
            return R.string.localizable.stakingUnbond_v190(preferredLanguages: locale.rLanguages)
        case .pendingRewards:
            return R.string.localizable.stakingPendingRewards_v2_0_0(preferredLanguages: locale.rLanguages)
        case .rewardDestination:
            return R.string.localizable.stakingRewardsDestinationTitle_v2_0_0(
                preferredLanguages: locale.rLanguages
            )
        case .changeValidators, .setupValidators:
            return R.string.localizable.stakingYourValidatorsTitle(preferredLanguages: locale.rLanguages)
        case .controllerAccount:
            return R.string.localizable.stakingControllerAccountTitle(preferredLanguages: locale.rLanguages)
        case .yourValidator:
            return R.string.localizable.stakingYourValidatorTitle(preferredLanguages: locale.rLanguages)
        }
    }

    func detailsForLocale(_ locale: Locale) -> String? {
        if case let .changeValidators(count) = self {
            guard let count = count else {
                return nil
            }

            let formatter = NumberFormatter.quantity.localizableResource().value(for: locale)
            return formatter.string(from: NSNumber(value: count))
        }

        return nil
    }

    var icon: UIImage? {
        switch self {
        case .stakeMore:
            return R.image.iconBondMore()
        case .unstake:
            return R.image.iconUnbond()
        case .pendingRewards:
            return R.image.iconPendingRewards()
        case .rewardDestination:
            return R.image.iconWallet()
        case .changeValidators, .setupValidators, .yourValidator:
            return R.image.iconValidators()
        case .controllerAccount:
            return R.image.iconAccount()
        }
    }
}
