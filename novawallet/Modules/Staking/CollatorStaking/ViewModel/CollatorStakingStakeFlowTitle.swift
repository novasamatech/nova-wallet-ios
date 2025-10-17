import Foundation
import Foundation_iOS

enum CollatorStakingStakeScreenTitle {
    case setup(hasStake: Bool, assetSymbol: String)
    case confirm(hasStake: Bool)

    private func getSetupTitle(
        hasStake: Bool,
        assetSymbol: String
    ) -> LocalizableResource<String> {
        if hasStake {
            return LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingBondMore_v190()
            }
        } else {
            return LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingStakeFormat(assetSymbol)
            }
        }
    }

    private func getConfirmTitle(hasStake: Bool) -> LocalizableResource<String> {
        if hasStake {
            LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingBondMore_v190()
            }
        } else {
            LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartTitle()
            }
        }
    }

    func callAsFunction() -> LocalizableResource<String> {
        switch self {
        case let .setup(hasStake, assetSymbol):
            return getSetupTitle(hasStake: hasStake, assetSymbol: assetSymbol)
        case let .confirm(hasStake):
            return getConfirmTitle(hasStake: hasStake)
        }
    }
}
