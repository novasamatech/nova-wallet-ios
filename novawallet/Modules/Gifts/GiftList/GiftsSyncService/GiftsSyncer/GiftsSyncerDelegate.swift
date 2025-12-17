protocol GiftsSyncerDelegate: AnyObject {
    func giftsSyncer(
        _ syncer: GiftsSyncerProtocol,
        didReceive status: GiftModel.Status,
        for giftAccountId: AccountId
    )

    func giftsSyncer(
        _ syncer: GiftsSyncerProtocol,
        didUpdateSyncingAccountIds accountIds: Set<AccountId>
    )
}
