import Foundation
import SubstrateSdk

protocol GenericLedgerAccountVMFactoryProtocol {
    func createViewModel(
        for account: GenericLedgerAccountModel,
        locale: Locale
    ) -> GenericLedgerAccountViewModel
}

final class GenericLedgerAccountVMFactory {
    let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating = PolkadotIconGenerator()) {
        self.iconGenerator = iconGenerator
    }
}

private extension GenericLedgerAccountVMFactory {
    func createIconViewModel(from accountId: AccountId) -> DrawableIconViewModel? {
        let icon = try? iconGenerator.generateFromAccountId(accountId)
        return icon.map { DrawableIconViewModel(icon: $0) }
    }

    func createAddressViewModel(
        from model: HardwareWalletAddressModel,
        locale: Locale
    ) -> GenericLedgerAddressViewModel {
        guard let accountId = model.accountId else {
            return GenericLedgerAddressViewModel(
                title: model.scheme.createTitle(for: locale),
                existence: .notFound
            )
        }

        let icon = createIconViewModel(from: accountId)

        let address = model.address ?? ""

        return GenericLedgerAddressViewModel(
            title: model.scheme.createTitle(for: locale),
            existence: .found(.init(address: address, icon: icon))
        )
    }
}

extension GenericLedgerAccountVMFactory: GenericLedgerAccountVMFactoryProtocol {
    func createViewModel(
        for account: GenericLedgerAccountModel,
        locale: Locale
    ) -> GenericLedgerAccountViewModel {
        let sortedAddresses = account.addresses

        let icon: DrawableIconViewModel? = sortedAddresses.first(where: { $0.accountId != nil })?.accountId.flatMap {
            createIconViewModel(from: $0)
        }

        let addressViewModels = sortedAddresses.map { address in
            createAddressViewModel(from: address, locale: locale)
        }

        return GenericLedgerAccountViewModel(
            title: R.string.localizable.commonIndexedAccount(
                "\(account.index + 1)",
                preferredLanguages: locale.rLanguages
            ),
            icon: icon,
            addresses: addressViewModels
        )
    }
}
