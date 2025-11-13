import Foundation
import Operation_iOS

protocol WalletListFilterProtocol {
    func apply(for wallets: [ManagedMetaAccountModel]) -> [ManagedMetaAccountModel]

    func apply(
        for changes: [DataProviderChange<ManagedMetaAccountModel>]
    ) -> [DataProviderChange<ManagedMetaAccountModel>]
}

struct GiftWalletListFilter: WalletListFilterProtocol {
    private let eligibleWallletTypes: Set<MetaAccountModelType> = [
        .secrets,
        .ledger,
        .genericLedger,
        .paritySigner,
        .polkadotVault
    ]

    func apply(for wallets: [ManagedMetaAccountModel]) -> [ManagedMetaAccountModel] {
        wallets.filter { eligibleWallletTypes.contains($0.info.type) }
    }

    func apply(
        for changes: [DataProviderChange<ManagedMetaAccountModel>]
    ) -> [DataProviderChange<ManagedMetaAccountModel>] {
        changes.filter { change in
            guard let item = change.item else { return true }

            return eligibleWallletTypes.contains(item.info.type)
        }
    }
}
