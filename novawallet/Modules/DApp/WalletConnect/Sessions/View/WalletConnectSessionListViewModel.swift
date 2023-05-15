import Foundation

struct WalletConnectSessionListViewModel: Hashable {
    let identifier: String
    let iconViewModel: ImageViewModelProtocol
    let title: String
    let wallet: DisplayWalletViewModel?

    static func == (lhs: WalletConnectSessionListViewModel, rhs: WalletConnectSessionListViewModel) -> Bool {
        lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
