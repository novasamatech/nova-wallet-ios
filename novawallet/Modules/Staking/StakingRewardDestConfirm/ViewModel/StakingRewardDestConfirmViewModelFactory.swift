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
    private lazy var addressIconGenerator = PolkadotIconGenerator()
    private lazy var walletIconGenerator = NovaIconGenerator()
    private lazy var amountFactory = AmountFormatterFactory()

    func createViewModel(
        from stashItem: StashItem,
        rewardDestination: RewardDestination<ChainAccountResponse>,
        controller: ChainAccountResponse?
    ) throws -> StakingRewardDestConfirmViewModel {
        let controllerAddressIcon = try addressIconGenerator.generateFromAddress(stashItem.controller)

        let rewardDestViewModel: RewardDestinationTypeViewModel

        switch rewardDestination {
        case .restake:
            rewardDestViewModel = .restake
        case let .payout(account):
            // TODO: Fix viewModel creation
            let walletIcon = try walletIconGenerator.generateFromAccountId(account.accountId)
            let walletIconViewModel = DrawableIconViewModel(icon: walletIcon)

            let payoutAddressIcon = try addressIconGenerator.generateFromAccountId(account.accountId)
            let payoutAddressIconViewModel = DrawableIconViewModel(icon: payoutAddressIcon)
            let payoutAddress = account.toAddress()

            let detailsViewModel = WalletAccountViewModel(
                walletName: account.name,
                walletIcon: walletIconViewModel,
                address: payoutAddress ?? "",
                addressIcon: payoutAddressIconViewModel
            )

            rewardDestViewModel = .payout(details: detailsViewModel)
        }

        return StakingRewardDestConfirmViewModel(
            senderIcon: controllerAddressIcon,
            senderName: controller?.name ?? stashItem.controller,
            rewardDestination: rewardDestViewModel
        )
    }
}
