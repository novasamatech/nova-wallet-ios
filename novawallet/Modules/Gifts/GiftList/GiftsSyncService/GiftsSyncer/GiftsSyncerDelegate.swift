protocol GiftsSyncerDelegate: AnyObject {
    func giftsSyncer(
        _ syncer: GiftsSyncer,
        didReceive status: GiftModel.Status,
        for giftAccountId: AccountId
    )

    func giftsSyncer(
        _ syncer: GiftsSyncer,
        didUpdateSyncingAccountIds accountIds: Set<AccountId>
    )
}
