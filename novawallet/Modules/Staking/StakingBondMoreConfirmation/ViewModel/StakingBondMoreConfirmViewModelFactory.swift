import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

protocol StakingBondMoreConfirmViewModelFactoryProtocol {
    func createViewModel(stash: MetaChainAccountResponse) throws -> StakingBondMoreConfirmViewModel
}

final class StakingBondMoreConfirmViewModelFactory: StakingBondMoreConfirmViewModelFactoryProtocol {
    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()

    func createViewModel(stash: MetaChainAccountResponse) throws -> StakingBondMoreConfirmViewModel {
        let viewModel = try walletViewModelFactory.createViewModel(from: stash)

        let walletViewModel = viewModel.displayWallet()
        let accountViewModel = viewModel.displayAddress()

        return StakingBondMoreConfirmViewModel(
            walletViewModel: walletViewModel,
            accountViewModel: accountViewModel
        )
    }
}
