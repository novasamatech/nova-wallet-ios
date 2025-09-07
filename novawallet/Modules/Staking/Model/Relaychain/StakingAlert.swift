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
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingChangeYourValidators()
        case .nominatorLowStake:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingBondMoreTokens()
        case .redeemUnbonded:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingRedeemUnbondedTokens()
        case .bondedSetValidators:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSetValidatorsTitle()
        case .waitingNextEra:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingNominatorStatusAlertWaitingMessage()
        case .rebag:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingImprovements()
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
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSetValidatorsMessage()
        case .waitingNextEra:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingAlertStartNextEraMessage()
        case .rebag:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingRebagAlertMessage()
        }
    }
}
