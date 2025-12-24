import Foundation

struct HardwareWalletAddressesViewModel {
    struct Section {
        let scheme: HardwareWalletAddressScheme
        let items: [ChainAccountViewModelItem]
    }

    let sections: [Section]
}
