import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

protocol StakingUnbondConfirmViewModelFactoryProtocol {
    func createUnbondConfirmViewModel(
        controllerItem: MetaChainAccountResponse
    ) throws -> StakingUnbondConfirmViewModel
}

final class StakingUnbondConfirmViewModelFactory: StakingUnbondConfirmViewModelFactoryProtocol {
    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()

    func createUnbondConfirmViewModel(
        controllerItem: MetaChainAccountResponse
    ) throws -> StakingUnbondConfirmViewModel {
        let walletViewModel = try walletViewModelFactory.createDisplayViewModel(from: controllerItem)
        let addressViewModel = try walletViewModelFactory.createViewModel(
            from: controllerItem.chainAccount.toAddress() ?? ""
        ).displayAddress()

        return StakingUnbondConfirmViewModel(
            walletViewModel: walletViewModel,
            accountViewModel: addressViewModel
        )
    }
}
