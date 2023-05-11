import Foundation

struct WalletConnectSessionViewModel {
    enum Status {
        case active
        case expired
    }

    let iconViewModel: ImageViewModelProtocol
    let title: String
    let wallet: DisplayWalletViewModel?
    let host: String
    let networks: DAppNetworksViewModel
    let status: Status
}
