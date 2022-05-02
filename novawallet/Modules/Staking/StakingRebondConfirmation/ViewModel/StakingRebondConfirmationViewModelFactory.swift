import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

protocol StakingRebondConfirmationViewModelFactoryProtocol {
    func createViewModel(controllerItem: MetaChainAccountResponse) throws -> StakingRebondConfirmationViewModel
}

final class StakingRebondConfirmationViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol {
    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()

    func createViewModel(
        controllerItem: MetaChainAccountResponse
    ) throws -> StakingRebondConfirmationViewModel {
        let walletViewModel = try walletViewModelFactory.createDisplayViewModel(from: controllerItem)
        let accountViewModel = try walletViewModelFactory.createViewModel(
            from: controllerItem.chainAccount.toAddress() ?? ""
        ).displayAddress()

        return StakingRebondConfirmationViewModel(
            walletViewModel: walletViewModel,
            addressViewModel: accountViewModel
        )
    }
}
