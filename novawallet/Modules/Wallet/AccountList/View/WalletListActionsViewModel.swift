import Foundation
import CommonWallet

final class WalletListActionsViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String { WalletAccountListConstants.actionsCellId }

    var itemHeight: CGFloat { WalletAccountListConstants.listActionsCellHeght }

    var command: WalletCommandProtocol? { nil }
}
