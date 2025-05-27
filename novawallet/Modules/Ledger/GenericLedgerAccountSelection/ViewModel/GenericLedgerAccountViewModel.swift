import Foundation

struct GenericLedgerAddressViewModel {
    struct Address {
        let address: String
        let icon: ImageViewModelProtocol?
    }
    
    enum AddressExistence {
        case found(Address)
        case notFound
    }
    
    let type: String
    let existence: AddressExistence
}

struct GenericIndexedLedgerAccountViewModel {
    let title: String
    let icon: ImageViewModelProtocol?
    let addresses: [GenericLedgerAddressViewModel]
}
