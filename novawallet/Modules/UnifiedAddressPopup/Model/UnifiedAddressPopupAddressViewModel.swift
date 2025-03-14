import Foundation

enum UnifiedAddressPopup {
    enum AddressFormat {
        case new(AddressViewModel)
        case legacy(AddressViewModel)
    }
    
    struct AddressViewModel {
        let formatText: String
        let addressText: String
    }
}
