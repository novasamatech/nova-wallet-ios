import Foundation
import FearlessUtils

protocol ManagedWalletViewModelFactoryProtocol {
    func createViewModelFromItem(_ item: ManagedMetaAccountModel) -> ManagedWalletViewModelItem
}

final class ManagedWalletViewModelFactory: ManagedWalletViewModelFactoryProtocol {
    let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func createViewModelFromItem(_ item: ManagedMetaAccountModel) -> ManagedWalletViewModelItem {
        let address = (try? item.info.substrateAccountId.toAddress(using: .substrate(42))) ?? ""
        let icon = try? iconGenerator.generateFromAddress(address)

        return ManagedWalletViewModelItem(
            identifier: item.identifier,
            name: item.info.name,
            icon: icon,
            isSelected: item.isSelected
        )
    }
}
