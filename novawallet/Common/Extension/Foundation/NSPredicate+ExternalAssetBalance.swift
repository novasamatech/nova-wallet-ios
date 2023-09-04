import Foundation

extension NSPredicate {
    static func externalAssetBalance(
        for chainAssetId: ChainAssetId,
        accountId: AccountId
    ) -> NSPredicate {
        let chainPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDExternalBalance.chainId),
            chainAssetId.chainId
        )

        let assetPredicate = NSPredicate(
            format: "%K == %d",
            #keyPath(CDExternalBalance.chainId),
            chainAssetId.assetId
        )

        let accountPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDExternalBalance.chainAccountId),
            accountId.toHex()
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [chainPredicate, assetPredicate, accountPredicate])
    }
}
