import Foundation_iOS

struct Web3NameAddressListViewModel {
    let title: LocalizableResource<String>?
    let items: [LocalizableResource<SelectableAddressTableViewCell.Model>]
    let selectedIndex: Int?
    let context: Web3NameAddressesSelectionState
}
