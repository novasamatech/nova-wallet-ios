import Foundation
import SubstrateSdk

protocol WalletSwitchViewModelFactoryProtocol {
    func createViewModel(from wallet: MetaAccountModel, hasNotification: Bool) -> WalletSwitchViewModel
}

final class WalletSwitchViewModelFactory {
    private lazy var iconGenerator = NovaIconGenerator()
}

extension WalletSwitchViewModelFactory: WalletSwitchViewModelFactoryProtocol {
    func createViewModel(from wallet: MetaAccountModel, hasNotification: Bool) -> WalletSwitchViewModel {
        WalletSwitchViewModel(
            name: wallet.name,
            type: wallet.type,
            hasNotification: hasNotification
        )
    }
}
