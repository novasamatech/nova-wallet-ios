import Foundation

struct WalletAccountViewModel {
    let walletName: String?
    let walletIcon: ImageViewModelProtocol?
    let address: String
    let addressIcon: ImageViewModelProtocol?
}

extension WalletAccountViewModel {
    static var empty: WalletAccountViewModel {
        WalletAccountViewModel(
            walletName: nil,
            walletIcon: nil,
            address: "",
            addressIcon: nil
        )
    }
}
