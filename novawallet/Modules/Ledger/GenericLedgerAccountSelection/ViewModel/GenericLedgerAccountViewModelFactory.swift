import Foundation
import SubstrateSdk

protocol GenericLedgerAccountVMFactoryProtocol {
    func createViewModel(
        for indexAccount: GenericLedgerIndexedAccountModel,
        locale: Locale
    ) -> GenericIndexedLedgerAccountViewModel
}

final class GenericLedgerAccountVMFactory {
    let iconGenerator: IconGenerating
    
    init(iconGenerator: IconGenerating = PolkadotIconGenerator()) {
        self.iconGenerator = iconGenerator
    }
}

private extension GenericLedgerAccountVMFactory: GenericLedgerAccountVMFactoryProtocol {
    func createIconViewModel(from address: AccountAddress) -> DrawableIconViewModel? {
        let icon = try? iconGenerator.generateFromAddress(address)
        return icon.map { DrawableIconViewModel(icon: $0) }
    }
    
    func createAddressViewModel(
        from model: GenericLedgerAddressModel,
        locale: Locale
    ) -> GenericLedgerAccountViewModel {
        guard let address = model.address else {
            return GenericLedgerAccountViewModel(
                type: model.type.createTitle(for: locale),
                existence: .notFound
            )
        }
        
        let icon = createIconViewModel(from: address)
        
        return GenericLedgerAddressViewModel(
            type: model.type.createTitle(for: locale),
            existence: .found(.init(address: address, icon: icon))
        )
    }
}

extension GenericLedgerAccountVMFactory: GenericLedgerAccountVMFactoryProtocol {
    func createViewModel(
        for indexAccount: GenericLedgerIndexedAccountModel,
        locale: Locale
    ) -> GenericIndexedLedgerAccountViewModel {
        let sortedAccounts = indexAccount.accounts.sorted { $0.type.order < $1.type.order }
        
        let icon: DrawableIconViewModel? = if let address = sortedAccounts.first(where: { $0.address != nil }) {
            createIconViewModel(from: address)
        } else {
            nil
        }
        
        let addressViewModels = sortedAccounts.map { account in
            createAccountViewModel(from: account, locale: locale)
        }
        
        return GenericIndexedLedgerAccountViewModel(
            title: "",
            icon: icon,
            addresses: addressViewModels
        )
    }
}
