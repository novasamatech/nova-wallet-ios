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
        let walletViewModel = try walletViewModelFactory.createDisplayViewModel(from: stash)
        let accountViewModel = try walletViewModelFactory.createViewModel(
            from: stash.chainAccount.toAddress() ?? ""
        ).displayAddress()

        return StakingBondMoreConfirmViewModel(
            walletViewModel: walletViewModel,
            accountViewModel: accountViewModel
        )
    }
}
