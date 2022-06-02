import Foundation
import SoraFoundation

protocol ParaStkAccountDetailsViewModelFactoryProtocol {
    func createViewModels(
        from bonds: [ParachainStaking.Bond],
        identities: [AccountId: AccountIdentity]?,
        disabled: Set<AccountId>
    ) -> [LocalizableResource<SelectableViewModel<AccountDetailsSelectionViewModel>>]
}

final class ParaStkAccountDetailsViewModelFactory {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let chainFormat: ChainFormat
    let assetPrecision: Int16

    private lazy var displayAddressFactory = DisplayAddressViewModelFactory()

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainFormat: ChainFormat,
        assetPrecision: Int16
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainFormat = chainFormat
        self.assetPrecision = assetPrecision
    }
}

extension ParaStkAccountDetailsViewModelFactory: ParaStkAccountDetailsViewModelFactoryProtocol {
    func createViewModels(
        from bonds: [ParachainStaking.Bond],
        identities: [AccountId: AccountIdentity]?,
        disabled: Set<AccountId>
    ) -> [AccountDetailsPickerViewModel] {
        bonds.map { bond in
            let addressViewModel: DisplayAddressViewModel
            let address = try? bond.owner.toAddress(using: chainFormat)

            if let name = identities?[bond.owner]?.displayName {
                let displayAddress = DisplayAddress(address: address ?? "", username: name)
                addressViewModel = displayAddressFactory.createViewModel(from: displayAddress)
            } else {
                addressViewModel = displayAddressFactory.createViewModel(from: address ?? "")
            }

            let amountDecimal = Decimal.fromSubstrateAmount(bond.amount, precision: assetPrecision) ?? 0
            let localizedAmountString = balanceViewModelFactory.amountFromValue(amountDecimal)
            let selectable = !disabled.contains(bond.owner)

            return LocalizableResource { locale in
                let detailsTitle = R.string.localizable.commonStakedPrefix(preferredLanguages: locale.rLanguages)
                let detailsSubtitle = localizedAmountString.value(for: locale)

                let details = TitleWithSubtitleViewModel(title: detailsTitle, subtitle: detailsSubtitle)

                let accountDetails = AccountDetailsSelectionViewModel(
                    displayAddress: addressViewModel,
                    details: details
                )

                return SelectableViewModel(underlyingViewModel: accountDetails, selectable: selectable)
            }
        }
    }
}
