import Foundation
import UIKit.UIImage
import Foundation_iOS

enum StakingAlert {
    case bondedSetValidators
    case nominatorChangeValidators(title: LocalizableResource<String>, details: LocalizableResource<String>)
    case nominatorLowStake(LocalizableResource<String>)
    case nominatorAllOversubscribed
    case redeemUnbonded(LocalizableResource<String>)
    case waitingNextEra
    case rebag
}

extension StakingAlert {
    var hasAssociatedAction: Bool {
        switch self {
        case .nominatorLowStake, .nominatorChangeValidators, .redeemUnbonded, .bondedSetValidators,
             .nominatorAllOversubscribed, .rebag:
            return true
        case .waitingNextEra:
            return false
        }
    }

    var icon: UIImage? {
        switch self {
        case .nominatorChangeValidators, .nominatorLowStake, .redeemUnbonded, .bondedSetValidators,
             .nominatorAllOversubscribed, .rebag:
            return R.image.iconWarning()
        case .waitingNextEra:
            return R.image.iconPending()
        }
    }

    func title(for locale: Locale) -> String {
        switch self {
        case let .nominatorChangeValidators(localizedTitle, _):
            return localizedTitle.value(for: locale)
        case .nominatorAllOversubscribed:
            return R.string.localizable.stakingChangeYourValidators(preferredLanguages: locale.rLanguages)
        case .nominatorLowStake:
            return R.string.localizable.stakingBondMoreTokens(preferredLanguages: locale.rLanguages)
        case .redeemUnbonded:
            return R.string.localizable.stakingRedeemUnbondedTokens(preferredLanguages: locale.rLanguages)
        case .bondedSetValidators:
            return R.string.localizable.stakingSetValidatorsTitle(preferredLanguages: locale.rLanguages)
        case .waitingNextEra:
            return R.string.localizable.stakingNominatorStatusAlertWaitingMessage(preferredLanguages: locale.rLanguages)
        case .rebag:
            return R.string.localizable.stakingImprovements(preferredLanguages: locale.rLanguages)
        }
    }

    func description(for locale: Locale) -> String {
        switch self {
        case let .nominatorChangeValidators(_, localizedString):
            return localizedString.value(for: locale)
        case .nominatorAllOversubscribed:
            return R.string.localizable
                .stakingYourOversubscribedMessage(preferredLanguages: locale.rLanguages)
        case let .nominatorLowStake(localizedString):
            return localizedString.value(for: locale)
        case let .redeemUnbonded(localizedString):
            return localizedString.value(for: locale)
        case .bondedSetValidators:
            return R.string.localizable.stakingSetValidatorsMessage(preferredLanguages: locale.rLanguages)
        case .waitingNextEra:
            return R.string.localizable.stakingAlertStartNextEraMessage(preferredLanguages: locale.rLanguages)
        case .rebag:
            return R.string.localizable.stakingRebagAlertMessage(preferredLanguages: locale.rLanguages)
        }
    }
}
