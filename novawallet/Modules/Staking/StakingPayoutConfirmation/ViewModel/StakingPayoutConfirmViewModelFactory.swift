import Foundation
import SubstrateSdk
import CommonWallet
import SoraFoundation

protocol StakingPayoutConfirmViewModelFactoryProtocol {
    func createPayoutConfirmViewModel(
        with account: MetaChainAccountResponse
    ) throws -> LocalizableResource<PayoutConfirmViewModel>
}

final class StakingPayoutConfirmViewModelFactory: StakingPayoutConfirmViewModelFactoryProtocol {
    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()

    func createPayoutConfirmViewModel(
        with account: MetaChainAccountResponse
    ) throws -> LocalizableResource<PayoutConfirmViewModel> {
        let walletViewModel = try walletViewModelFactory.createDisplayViewModel(from: account)
        let addressViewModel = try walletViewModelFactory.createViewModel(
            from: account.chainAccount.toAddress() ?? ""
        ).displayAddress()

        return LocalizableResource { _ in
            PayoutConfirmViewModel(walletViewModel: walletViewModel, accountViewModel: addressViewModel)
        }
    }
}
