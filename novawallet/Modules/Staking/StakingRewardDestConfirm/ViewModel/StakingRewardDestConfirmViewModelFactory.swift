import Foundation
import SubstrateSdk

protocol StakingRewardDestConfirmVMFactoryProtocol {
    func createViewModel(
        from stashItem: StashItem,
        rewardDestination: RewardDestination<ChainAccountResponse>,
        controller: ChainAccountResponse?
    ) throws -> StakingRewardDestConfirmViewModel
}

final class StakingRewardDestConfirmVMFactory: StakingRewardDestConfirmVMFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var amountFactory = AmountFormatterFactory()

    func createViewModel(
        from stashItem: StashItem,
        rewardDestination: RewardDestination<ChainAccountResponse>,
        controller: ChainAccountResponse?
    ) throws -> StakingRewardDestConfirmViewModel {
        let icon = try iconGenerator.generateFromAddress(stashItem.controller)

        let rewardDestViewModel: RewardDestinationTypeViewModel

        switch rewardDestination {
        case .restake:
            rewardDestViewModel = .restake
        case let .payout(account):
            let payoutIcon = try iconGenerator.generateFromAccountId(account.accountId)

            rewardDestViewModel = .payout(icon: payoutIcon, title: account.name)
        }

        return StakingRewardDestConfirmViewModel(
            senderIcon: icon,
            senderName: controller?.name ?? stashItem.controller,
            rewardDestination: rewardDestViewModel
        )
    }
}
