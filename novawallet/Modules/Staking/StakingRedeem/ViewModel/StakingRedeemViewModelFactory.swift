import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

protocol StakingRedeemViewModelFactoryProtocol {
    func createRedeemViewModel(controllerItem: MetaChainAccountResponse) throws -> StakingRedeemViewModel
}

final class StakingRedeemViewModelFactory: StakingRedeemViewModelFactoryProtocol {
    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()

    func createRedeemViewModel(controllerItem: MetaChainAccountResponse) throws -> StakingRedeemViewModel {
        let walletViewModel = try walletViewModelFactory.createDisplayViewModel(from: controllerItem)
        let accountViewModel = try walletViewModelFactory.createViewModel(
            from: controllerItem.chainAccount.toAddress() ?? ""
        ).displayAddress()

        return StakingRedeemViewModel(
            walletViewModel: walletViewModel,
            accountViewModel: accountViewModel
        )
    }
}
