import SoraFoundation
protocol Web3NameViewModelFactoryProtocol {
    func recipientListViewModel(
        kiltRecipients: [KiltTransferAssetRecipientAccount],
        for name: String,
        chainName: String,
        selectedAddress: String?
    ) -> Web3NameAddressListViewModel
}

final class Web3NameViewModelFactory {
    private let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol

    init(displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol) {
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
    }

    private func recipientCellModel(
        selectedRecipientAddress: AccountAddress?,
        recipient: KiltTransferAssetRecipientAccount
    ) -> SelectableAddressTableViewCell.Model {
        let displayAddress = DisplayAddress(
            address: recipient.account,
            username: recipient.description ?? ""
        )
        let addressModel = displayAddressViewModelFactory
            .createViewModel(from: displayAddress)
            .withPlaceholder(image: R.image.iconAddressPlaceholder()!)

        return SelectableAddressTableViewCell.Model(
            address: addressModel,
            selected: selectedRecipientAddress == recipient.account
        )
    }
}

extension Web3NameViewModelFactory: Web3NameViewModelFactoryProtocol {
    func recipientListViewModel(
        kiltRecipients: [KiltTransferAssetRecipientAccount],
        for name: String,
        chainName: String,
        selectedAddress: String?
    ) -> Web3NameAddressListViewModel {
        let title = LocalizableResource<String> { locale in
            R.string.localizable.transferSetupKiltAddressesTitle(
                chainName,
                KiltW3n.fullName(for: name),
                preferredLanguages: locale.rLanguages
            )
        }

        let items = kiltRecipients.map {
            recipientCellModel(
                selectedRecipientAddress: selectedAddress,
                recipient: $0
            )
        }

        let localizableItems = items.map { item in
            LocalizableResource { _ in item }
        }

        let context = KiltAddressesSelectionState(accounts: kiltRecipients, name: name)

        return .init(
            title: title,
            items: localizableItems,
            selectedIndex: items.firstIndex(where: { $0.selected }),
            context: context
        )
    }
}
