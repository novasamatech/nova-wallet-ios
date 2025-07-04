import Foundation
import SubstrateSdk

struct WalletsCheckmarkViewModel {
    let identifier: String
    let walletViewModel: WalletView.ViewModel
    let checked: Bool

    init(
        identifier: String,
        walletViewModel: WalletView.ViewModel,
        checked: Bool
    ) {
        self.identifier = identifier
        self.walletViewModel = walletViewModel
        self.checked = checked
    }
}
