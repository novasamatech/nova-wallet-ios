import Foundation
import FearlessUtils

protocol ChainAccountViewModelFactoryProtocol {
    func createViewModelFromItem(_ item: ChainModel) -> ChainAccountViewModelItem
    func createChainViewModel() -> ChainAccountViewModelItem
    func createViewModel() -> ChainAccountListViewModel
}

final class ChainAccountViewModelFactory {
    let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }
}

extension ChainAccountViewModelFactory: ChainAccountViewModelFactoryProtocol {
    func createViewModelFromItem(_: ChainModel) -> ChainAccountViewModelItem {
        let address = "" // FIXME: (try? item.info.substrateAccountId.toAddress(using: .substrate(42))) ??
        let icon = try? iconGenerator.generateFromAddress(address)

        return ChainAccountViewModelItem(
            name: "Kusamka",
            address: "123ouh1ieyglafqliuheoq134",
            chainIcon: R.image.iconKsmAsset()!,
            accountIcon: icon
        )
    }

    func createChainViewModel() -> ChainAccountViewModelItem {
        let address = "" // FIXME: (try? item.info.substrateAccountId.toAddress(using: .substrate(42))) ??
        let icon = try? iconGenerator.generateFromAddress(address)

        return ChainAccountViewModelItem(
            name: "Kusamka",
            address: "123ouh1ieyglafqliuheoq134",
            chainIcon: R.image.iconKsmAsset()!,
            accountIcon: icon
        )
    }

    func createViewModel() -> ChainAccountListViewModel {
        [
            ChainAccountListSectionViewModel(
                section: .customSecret, chainAccounts: [createChainViewModel()]
            ),
            ChainAccountListSectionViewModel(
                section: .sharedSecret, chainAccounts: [
                    createChainViewModel(),
                    createChainViewModel(),
                    createChainViewModel(),
                    createChainViewModel()
                ]
            )
        ]
    }
}

// TODO: Remove comments

// protocol ManagedAccountViewModelFactoryProtocol {
//    func createViewModelFromItem(_ item: ManagedMetaAccountModel) -> ManagedAccountViewModelItem
// }
//
// final class ManagedAccountViewModelFactory: ManagedAccountViewModelFactoryProtocol {
//    let iconGenerator: IconGenerating
//
//    init(iconGenerator: IconGenerating) {
//        self.iconGenerator = iconGenerator
//    }
//
//    func createViewModelFromItem(_ item: ManagedMetaAccountModel) -> ManagedAccountViewModelItem {
//        let address = (try? item.info.substrateAccountId.toAddress(using: .substrate(42))) ?? ""
//        let icon = try? iconGenerator.generateFromAddress(address)
//
//        return ManagedAccountViewModelItem(
//            identifier: item.identifier,
//            name: item.info.name,
//            address: address,
//            icon: icon,
//            isSelected: item.isSelected
//        )
//    }
// }
