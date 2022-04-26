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

    func displayAddress() -> DisplayAddressViewModel {
        DisplayAddressViewModel(
            address: address,
            name: walletName,
            imageViewModel: addressIcon
        )
    }

    func rawDisplayAddress() -> DisplayAddressViewModel {
        DisplayAddressViewModel(
            address: address,
            name: nil,
            imageViewModel: addressIcon
        )
    }

    func displayWallet() -> DisplayWalletViewModel {
        DisplayWalletViewModel(name: walletName ?? "", imageViewModel: walletIcon)
    }
}
