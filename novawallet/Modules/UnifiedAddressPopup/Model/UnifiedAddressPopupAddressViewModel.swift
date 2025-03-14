import Foundation

enum UnifiedAddressPopup {
    struct ViewModel {
        let titleText: String
        let subtitleText: String
        let newAddress: AddressViewModel
        let legacyAddress: AddressViewModel
        let checkboxText: String
        let checkboxSelected: Bool
        let buttonText: String
    }

    struct AddressViewModel {
        let formatText: String
        let addressText: String
    }
}
