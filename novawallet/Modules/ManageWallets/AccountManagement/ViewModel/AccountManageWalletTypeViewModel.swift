import Foundation
import UIKit

struct AccountManageWalletViewModel {
    let messageType: MessageType
    let context: WalletContext?
}

extension AccountManageWalletViewModel {
    typealias BannerViewModel = LedgerMigrationBannerView.ViewModel

    enum MessageType {
        case hint(text: String, icon: UIImage?)
        case banner(BannerViewModel)
        case none
    }

    enum WalletContext {
        case proxied(Proxied)
        case multisig(Multisig)
    }
}

extension AccountManageWalletViewModel.WalletContext {
    struct Multisig {
        let signatory: AccountDelegateViewModel
        let otherSignatories: [WalletInfoView<WalletView>.ViewModel]
        let otherSignatoriesTitle: String
        let signatoryInfoClosure: (String) -> Void
    }

    struct Proxied {
        let proxy: AccountDelegateViewModel
    }
}
