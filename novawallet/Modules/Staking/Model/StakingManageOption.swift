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
    case yieldBoost(enabled: Bool)
    case addProxy
    case editProxies(currentCount: Int)

    func titleForLocale(_ locale: Locale, statics: StakingMainStaticViewModelProtocol?) -> String {
        switch self {
        case .stakeMore:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingBondMore_v190()
        case .unstake:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingUnbond_v190()
        case .pendingRewards:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingPendingRewards_v2_0_0()
        case .rewardDestination:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingRewardsDestinationTitle_v2_0_0()
        case .changeValidators, .setupValidators:
            if let statics = statics {
                return statics.actionsYourValidators(for: locale)
            } else {
                return R.string(preferredLanguages: locale.rLanguages).localizable.stakingYourValidatorsTitle()
            }
        case .controllerAccount:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingControllerAccountTitle()
        case .yourValidator:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingYourValidatorTitle()
        case .yieldBoost:
            return R.string(preferredLanguages: locale.rLanguages).localizable.commonYieldBoost()
        case .addProxy:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSetupAddYourProxy()
        case .editProxies:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSetupYourProxies()
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

        if case let .yieldBoost(enabled) = self {
            if enabled {
                return R.string(preferredLanguages: locale.rLanguages).localizable.commonOn().capitalized
            } else {
                return R.string(preferredLanguages: locale.rLanguages).localizable.commonOff().capitalized
            }
        }

        if case let .editProxies(count) = self {
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
            return R.image.iconRewardsDest()
        case .changeValidators, .setupValidators, .yourValidator:
            return R.image.iconValidators()
        case .controllerAccount:
            return R.image.iconControllerAccount()
        case .yieldBoost:
            return R.image.iconYieldBoost()
        case .addProxy, .editProxies:
            return R.image.iconDelegate()
        }
    }

    static func proxyAction(
        from proxyDefinition: UncertainStorage<ProxyDefinition?>,
        chain: ChainModel
    ) -> StakingManageOption? {
        guard proxyDefinition.isDefined, chain.hasProxy else {
            return nil
        }
        let proxiesCount = proxyDefinition.value??.definition.count ?? 0
        if proxiesCount > 0 {
            return .editProxies(currentCount: proxiesCount)
        } else {
            return .addProxy
        }
    }
}
