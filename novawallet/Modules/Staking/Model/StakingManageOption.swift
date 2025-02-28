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
            if let statics = statics {
                return statics.actionsYourValidators(for: locale)
            } else {
                return R.string.localizable.stakingYourValidatorsTitle(preferredLanguages: locale.rLanguages)
            }
        case .controllerAccount:
            return R.string.localizable.stakingControllerAccountTitle(preferredLanguages: locale.rLanguages)
        case .yourValidator:
            return R.string.localizable.stakingYourValidatorTitle(preferredLanguages: locale.rLanguages)
        case .yieldBoost:
            return R.string.localizable.commonYieldBoost(preferredLanguages: locale.rLanguages)
        case .addProxy:
            return R.string.localizable.stakingSetupAddYourProxy(preferredLanguages: locale.rLanguages)
        case .editProxies:
            return R.string.localizable.stakingSetupYourProxies(preferredLanguages: locale.rLanguages)
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
                return R.string.localizable.commonOn(preferredLanguages: locale.rLanguages).capitalized
            } else {
                return R.string.localizable.commonOff(preferredLanguages: locale.rLanguages).capitalized
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
