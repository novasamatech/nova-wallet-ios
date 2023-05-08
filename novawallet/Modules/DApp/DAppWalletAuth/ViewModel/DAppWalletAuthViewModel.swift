import Foundation

struct DAppWalletAuthViewModel {
    let sourceImageViewModel: ImageViewModelProtocol?
    let destinationImageViewModel: ImageViewModelProtocol?
    let dAppName: String
    let dAppHost: String
    let networks: DAppNetworksViewModel
    let networksWarning: String?
    let wallet: WalletTotalAmountView.ViewModel
    let walletWarning: String?

    var canApprove: Bool {
        networksWarning != nil || walletWarning != nil
    }
}
