import Foundation
import Foundation_iOS

struct HardwareWalletAddressesViewModel {
    struct Section {
        let title: LocalizableResource<String>
        let items: [ChainAccountViewModelItem]

        init(title: LocalizableResource<String>, items: [ChainAccountViewModelItem]) {
            self.title = title
            self.items = items
        }

        init(addressScheme: HardwareWalletAddressScheme, items: [ChainAccountViewModelItem]) {
            switch addressScheme {
            case .substrate:
                title = LocalizableResource { locale in
                    R.string.localizable.accountsSubstrate(
                        preferredLanguages: locale.rLanguages
                    ).uppercased()
                }
            case .evm:
                title = LocalizableResource { locale in
                    R.string.localizable.accountsEvm(
                        preferredLanguages: locale.rLanguages
                    ).uppercased()
                }
            }

            self.items = items
        }
    }

    let sections: [Section]
}
