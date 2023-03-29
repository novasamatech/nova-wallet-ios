protocol Web3NameViewModelFactoryProtocol {
    func w3nRecipientCellModel(
        selectedRecipientAddress: AccountAddress?,
        recipient: KiltTransferAssetRecipientAccount
    ) -> SelectableAddressTableViewCell.Model
}

final class Web3NameViewModelFactory: Web3NameViewModelFactoryProtocol {
    private let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol

    init(displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol) {
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
    }

    func w3nRecipientCellModel(
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
