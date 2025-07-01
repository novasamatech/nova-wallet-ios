import Foundation

struct GenericLedgerAddressViewModel {
    struct Found {
        let address: String
        let icon: ImageViewModelProtocol?
    }

    enum Existence {
        case found(Found)
        case notFound
    }

    let title: String
    let existence: Existence
}

struct GenericLedgerAccountViewModel {
    let title: String
    let icon: ImageViewModelProtocol?
    let addresses: [GenericLedgerAddressViewModel]
}
