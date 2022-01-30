import Foundation
import IrohaCrypto

extension NSPredicate {
    static func filterTransactionsBy(
        address: String,
        chainId: ChainModel.Id,
        assetId: UInt32
    ) -> NSPredicate {
        let senderPredicate = filterTransactionsBySender(address: address)
        let receiverPredicate = filterTransactionsByReceiver(address: address)
        let chainPredicate = filterTransactionsByChainId(chainId)
        let assetPredicate = filterTransactionsByAssetId(assetId)

        let orPredicates = [senderPredicate, receiverPredicate]
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainPredicate,
            assetPredicate,
            NSCompoundPredicate(orPredicateWithSubpredicates: orPredicates)
        ])
    }

    static func filterUtilityAssetTransactionsBy(
        address: String,
        chainId: ChainModel.Id,
        utilityAssetId: UInt32
    ) -> NSPredicate {
        let senderPredicate = filterTransactionsBySender(address: address)
        let receiverPredicate = filterTransactionsByReceiver(address: address)
        let chainPredicate = filterTransactionsByChainId(chainId)
        let assetPredicate = filterTransactionsByAssetId(utilityAssetId)

        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainPredicate,
            NSCompoundPredicate(
                orPredicateWithSubpredicates: [
                    senderPredicate,
                    NSCompoundPredicate(andPredicateWithSubpredicates: [
                        assetPredicate,
                        receiverPredicate
                    ])
                ]
            )
        ])
    }

    static func filterTransactionsBySender(address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDTransactionHistoryItem.sender), address)
    }

    static func filterTransactionsByReceiver(address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDTransactionHistoryItem.receiver), address)
    }

    static func filterTransactionsByChainId(_ chainId: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDTransactionHistoryItem.chainId), chainId)
    }

    static func filterTransactionsByAssetId(_ assetId: UInt32) -> NSPredicate {
        NSPredicate(format: "%K == %d", #keyPath(CDTransactionHistoryItem.assetId), assetId)
    }

    static func filterContactsByTarget(address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDContactItem.targetAddress), address)
    }

    static func filterRuntimeMetadataItemsBy(identifier: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDRuntimeMetadataItem.identifier), identifier)
    }

    static func filterStorageItemsBy(identifier: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDChainStorageItem.identifier), identifier)
    }

    static func filterByIdPrefix(_ prefix: String) -> NSPredicate {
        NSPredicate(format: "%K BEGINSWITH %@", #keyPath(CDChainStorageItem.identifier), prefix)
    }

    static func filterByStash(_ address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDStashItem.stash), address)
    }

    static func filterByStashOrController(_ address: String) -> NSPredicate {
        let stash = filterByStash(address)
        let controller = NSPredicate(format: "%K == %@", #keyPath(CDStashItem.controller), address)

        return NSCompoundPredicate(orPredicateWithSubpredicates: [stash, controller])
    }

    static func filterMetaAccountByAccountId(_ accountId: AccountId) -> NSPredicate {
        let hexAccountId = accountId.toHex()

        let substrateAccountFilter = NSPredicate(
            format: "%K == %@",
            #keyPath(CDMetaAccount.substrateAccountId), hexAccountId
        )

        let ethereumAccountFilter = NSPredicate(
            format: "%K == %@",
            #keyPath(CDMetaAccount.ethereumAddress), hexAccountId
        )

        let chainAccountFilter = NSPredicate(
            format: "ANY %K == %@",
            #keyPath(CDMetaAccount.chainAccounts.accountId), hexAccountId
        )

        return NSCompoundPredicate(orPredicateWithSubpredicates: [
            substrateAccountFilter,
            ethereumAccountFilter,
            chainAccountFilter
        ])
    }

    static func selectedMetaAccount() -> NSPredicate {
        NSPredicate(format: "%K == true", #keyPath(CDMetaAccount.isSelected))
    }

    static func relayChains() -> NSPredicate {
        NSPredicate(format: "%K = nil", #keyPath(CDChain.parentId))
    }

    static func chainBy(identifier: ChainModel.Id) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDChain.chainId), identifier)
    }

    static func hasCrowloans() -> NSPredicate {
        NSPredicate(format: "%K == true", #keyPath(CDChain.hasCrowdloans))
    }

    static func assetBalance(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) -> NSPredicate {
        let accountPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetBalance.chainAccountId),
            accountId.toHex()
        )

        let chainIdPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetBalance.chainId),
            chainId
        )

        let assetIdPredicate = NSPredicate(
            format: "%K == %d",
            #keyPath(CDAssetBalance.assetId),
            assetId
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            accountPredicate, chainIdPredicate, assetIdPredicate
        ])
    }
}
