import Foundation
import SubstrateSdk
import CommonWallet
import SoraFoundation

protocol SelectValidatorsConfirmViewModelFactoryProtocol {
    func createViewModel(
        from state: SelectValidatorsConfirmationModel,
        assetInfo: AssetBalanceDisplayInfo
    ) throws
        -> LocalizableResource<SelectValidatorsConfirmViewModel>

    func createHints(from duration: StakingDuration) -> LocalizableResource<[TitleIconViewModel]>
}

final class SelectValidatorsConfirmViewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var amountFactory = AssetBalanceFormatterFactory()

    func createHints(from duration: StakingDuration) -> LocalizableResource<[TitleIconViewModel]> {
        LocalizableResource { locale in
            let eraDurationString = R.string.localizable.commonHoursFormat(
                format: duration.era.hoursFromSeconds,
                preferredLanguages: locale.rLanguages
            )

            let unlockingDurationString = R.string.localizable.commonDaysFormat(
                format: duration.unlocking.daysFromSeconds,
                preferredLanguages: locale.rLanguages
            )

            return [
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintRewardsFormat_v2_2_0(
                        eraDurationString,
                        preferredLanguages: locale.rLanguages
                    ),
                    icon: R.image.iconStarGray16()
                ),
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintUnstakeFormat_v2_2_0(
                        unlockingDurationString,
                        preferredLanguages: locale.rLanguages
                    ),
                    icon: R.image.iconStarGray16()
                ),
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintNoRewards_V2_2_0(
                        preferredLanguages: locale.rLanguages
                    ),
                    icon: R.image.iconStarGray16()
                ),
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintRedeem_v2_2_0(
                        preferredLanguages: locale.rLanguages
                    ),
                    icon: R.image.iconStarGray16()
                )
            ]
        }
    }

    func createViewModel(
        from state: SelectValidatorsConfirmationModel,
        assetInfo: AssetBalanceDisplayInfo
    ) throws
        -> LocalizableResource<SelectValidatorsConfirmViewModel> {
        let icon = try iconGenerator.generateFromAddress(state.wallet.address)

        let amountFormatter = amountFactory.createInputFormatter(for: assetInfo)

        let rewardViewModel: RewardDestinationTypeViewModel

        switch state.rewardDestination {
        case .restake:
            rewardViewModel = .restake
        case let .payout(account):
            let payoutIcon = try iconGenerator.generateFromAddress(account.address)

            rewardViewModel = .payout(icon: payoutIcon, title: account.username)
        }

        return LocalizableResource { locale in
            let amount = amountFormatter.value(for: locale).string(from: state.amount as NSNumber)

            return SelectValidatorsConfirmViewModel(
                senderIcon: icon,
                senderName: state.wallet.username,
                amount: amount ?? "",
                rewardDestination: rewardViewModel,
                validatorsCount: state.targets.count,
                maxValidatorCount: state.maxTargets
            )
        }
    }
}
