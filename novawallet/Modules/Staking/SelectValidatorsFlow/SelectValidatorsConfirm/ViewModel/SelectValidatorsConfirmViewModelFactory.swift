import Foundation
import SubstrateSdk

import Foundation_iOS

protocol SelectValidatorsConfirmViewModelFactoryProtocol {
    func createViewModel(
        from state: SelectValidatorsConfirmationModel
    ) throws -> SelectValidatorsConfirmViewModel

    func createStartStakingHints(from duration: StakingDuration) -> LocalizableResource<[String]>

    func createChangeValidatorsHints() -> LocalizableResource<[String]>
}

final class SelectValidatorsConfirmViewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol {
    private lazy var walletAccountViewModelFactory = WalletAccountViewModelFactory()

    func createStartStakingHints(from duration: StakingDuration) -> LocalizableResource<[String]> {
        LocalizableResource { locale in
            let eraDurationString = R.string(preferredLanguages: locale.rLanguages
            ).localizable.commonHoursFormat(format: duration.era.hoursFromSeconds)

            let unlockingDurationString = duration.unlocking.localizedDaysHours(for: locale)

            return [
                R.string(preferredLanguages: locale.rLanguages
                ).localizable.stakingHintRewardsFormat_v2_2_0(eraDurationString),
                R.string.localizable.stakingHintUnstakeFormat_v2_2_0(
                    "~\(unlockingDurationString)",
                    preferredLanguages: locale.rLanguages
                ),
                R.string(preferredLanguages: locale.rLanguages
                ).localizable.stakingHintNoRewards_v2_2_0(),
                R.string(preferredLanguages: locale.rLanguages
                ).localizable.stakingHintRedeem_v2_2_0()
            ]
        }
    }

    func createChangeValidatorsHints() -> LocalizableResource<[String]> {
        LocalizableResource { locale in
            [
                R.string(preferredLanguages: locale.rLanguages
                ).localizable.stakingYourValidatorsChangingTitle()
            ]
        }
    }

    func createViewModel(
        from state: SelectValidatorsConfirmationModel
    ) throws -> SelectValidatorsConfirmViewModel {
        let genericViewModel = try walletAccountViewModelFactory.createViewModel(from: state.wallet)

        let rewardViewModel: RewardDestinationTypeViewModel?

        if !state.hasExistingBond {
            switch state.rewardDestination {
            case .restake:
                rewardViewModel = .restake
            case let .payout(account):
                let viewModel = try walletAccountViewModelFactory.createViewModel(from: account.address)
                rewardViewModel = .payout(details: viewModel)
            }
        } else {
            rewardViewModel = nil
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
