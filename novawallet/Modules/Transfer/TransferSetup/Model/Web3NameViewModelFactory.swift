import Foundation_iOS
protocol Web3NameViewModelFactoryProtocol {
    func recipientListViewModel(
        recipients: [Web3TransferRecipient],
        for name: String,
        chain: ChainModel,
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
        recipient: Web3TransferRecipient,
        chainFormat: ChainFormat
    ) -> SelectableAddressTableViewCell.Model {
        let displayAddress = DisplayAddress(
            address: recipient.account,
            username: recipient.description ?? ""
        )
        let addressModel = displayAddressViewModelFactory
            .createViewModel(from: displayAddress, using: chainFormat)
            .withPlaceholder(image: R.image.iconAddressPlaceholder32()!)

        return SelectableAddressTableViewCell.Model(
            address: addressModel,
            selected: selectedRecipientAddress == recipient.account
        )
    }
}

extension Web3NameViewModelFactory: Web3NameViewModelFactoryProtocol {
    func recipientListViewModel(
        recipients: [Web3TransferRecipient],
        for name: String,
        chain: ChainModel,
        selectedAddress: String?
    ) -> Web3NameAddressListViewModel {
        let title = LocalizableResource<String> { locale in
            R.string.localizable.transferSetupKiltAddressesTitle(
                chain.name,
                KiltW3n.fullName(for: name),
                preferredLanguages: locale.rLanguages
            )
        }

        let items = recipients.map {
            recipientCellModel(
                selectedRecipientAddress: selectedAddress,
                recipient: $0,
                chainFormat: chain.chainFormat
            )
        }

        let localizableItems = items.map { item in
            LocalizableResource { _ in item }
        }

        let context = Web3NameAddressesSelectionState(accounts: recipients, name: name)

        return .init(
            title: title,
            items: localizableItems,
            selectedIndex: items.firstIndex(where: { $0.selected }),
            context: context
        )
    }
}
