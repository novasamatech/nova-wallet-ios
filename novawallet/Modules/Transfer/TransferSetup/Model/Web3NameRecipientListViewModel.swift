import SoraFoundation

struct Web3NameAddressListViewModel {
    let title: LocalizableResource<String>?
    let items: [LocalizableResource<SelectableAddressTableViewCell.Model>]
    let selectedIndex: Int?
    let context: KiltAddressesSelectionState
}
