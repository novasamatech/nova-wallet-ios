import Foundation

protocol StakingAnalyticsLocalSubscriptionHandler {
    func handleWeaklyRewardAnalytics(
        result: Result<[SubqueryRewardItemData]?, Error>,
        address: AccountAddress,
        urls: [URL]
    )
}

extension StakingAnalyticsLocalSubscriptionHandler {
    func handleWeaklyRewardAnalytics(
        result _: Result<[SubqueryRewardItemData]?, Error>,
        address _: AccountAddress,
        urls _: [URL]
    ) {}
}
