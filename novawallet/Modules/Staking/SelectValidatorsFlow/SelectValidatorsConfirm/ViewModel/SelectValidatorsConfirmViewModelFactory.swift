import Foundation
import SubstrateSdk
import CommonWallet
import SoraFoundation

protocol SelectValidatorsConfirmViewModelFactoryProtocol {
    func createViewModel(
        from state: SelectValidatorsConfirmationModel,
        assetInfo: AssetBalanceDisplayInfo
    ) throws -> SelectValidatorsConfirmViewModel

    func createHints(from duration: StakingDuration) -> LocalizableResource<[String]>
}

final class SelectValidatorsConfirmViewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol {
    private lazy var walletAccountViewModelFactory = WalletAccountViewModelFactory()

    func createHints(from duration: StakingDuration) -> LocalizableResource<[String]> {
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
                R.string.localizable.stakingHintRewardsFormat_v2_2_0(
                    eraDurationString,
                    preferredLanguages: locale.rLanguages
                ),
                R.string.localizable.stakingHintUnstakeFormat_v2_2_0(
                    unlockingDurationString,
                    preferredLanguages: locale.rLanguages
                ),
                R.string.localizable.stakingHintNoRewards_V2_2_0(
                    preferredLanguages: locale.rLanguages
                ),
                R.string.localizable.stakingHintRedeem_v2_2_0(
                    preferredLanguages: locale.rLanguages
                )
            ]
        }
    }

    func createViewModel(
        from state: SelectValidatorsConfirmationModel,
        assetInfo _: AssetBalanceDisplayInfo
    ) throws -> SelectValidatorsConfirmViewModel {
        let genericViewModel = try walletAccountViewModelFactory.createViewModel(from: state.wallet)

        let rewardViewModel: RewardDestinationTypeViewModel

        switch state.rewardDestination {
        case .restake:
            rewardViewModel = .restake
        case let .payout(account):
            let viewModel = try walletAccountViewModelFactory.createViewModel(from: account.address)
            rewardViewModel = .payout(details: viewModel)
        }

        return SelectValidatorsConfirmViewModel(
            walletViewModel: genericViewModel.displayWallet(),
            accountViewModel: genericViewModel.rawDisplayAddress(),
            rewardDestination: rewardViewModel,
            validatorsCount: state.targets.count,
            maxValidatorCount: state.maxTargets
        )
    }
}
