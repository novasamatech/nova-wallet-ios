import Foundation

extension NSPredicate {
    static func stakingDashboardItem(
        for chainAssetId: ChainAssetId,
        walletId: MetaAccountModel.Id
    ) -> NSPredicate {
        let chainPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDStakingDashboardItem.chainId),
            chainAssetId.chainId
        )

        let assetPredicate = NSPredicate(
            format: "%K == %d",
            #keyPath(CDStakingDashboardItem.assetId),
            chainAssetId.assetId
        )

        let accountPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDStakingDashboardItem.walletId),
            walletId
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [chainPredicate, assetPredicate, accountPredicate])
    }
}
