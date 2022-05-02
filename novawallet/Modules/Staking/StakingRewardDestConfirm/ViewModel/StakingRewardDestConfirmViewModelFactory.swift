import Foundation
import SubstrateSdk

protocol StakingRewardDestConfirmVMFactoryProtocol {
    func createViewModel(
        rewardDestination: RewardDestination<MetaChainAccountResponse>,
        controller: MetaChainAccountResponse
    ) throws -> StakingRewardDestConfirmViewModel
}

final class StakingRewardDestConfirmVMFactory: StakingRewardDestConfirmVMFactoryProtocol {
    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var amountFactory = AmountFormatterFactory()

    func createViewModel(
        rewardDestination: RewardDestination<MetaChainAccountResponse>,
        controller: MetaChainAccountResponse
    ) throws -> StakingRewardDestConfirmViewModel {
        let walletDetails = try walletViewModelFactory.createViewModel(from: controller)
        let accountViewModel = walletDetails.rawDisplayAddress()
        let walletViewModel = walletDetails.displayWallet()

        let rewardDestViewModel: RewardDestinationTypeViewModel

        switch rewardDestination {
        case .restake:
            rewardDestViewModel = .restake
        case let .payout(account):
            let payoutViewModel = try walletViewModelFactory.createViewModel(from: account)
            rewardDestViewModel = .payout(details: payoutViewModel)
        }

        return StakingRewardDestConfirmViewModel(
            walletViewModel: walletViewModel,
            accountViewModel: accountViewModel,
            rewardDestination: rewardDestViewModel
        )
    }
}
