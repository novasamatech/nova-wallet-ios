protocol GiftsStatusTrackerDelegate: AnyObject {
    func giftsTracker(
        _ tracker: GiftsStatusTrackerProtocol,
        didReceive status: GiftModel.Status,
        for giftAccountId: AccountId
    )

    func giftsTracker(
        _ tracker: GiftsStatusTrackerProtocol,
        didUpdateTrackingAccountIds accountIds: Set<AccountId>
    )
}
