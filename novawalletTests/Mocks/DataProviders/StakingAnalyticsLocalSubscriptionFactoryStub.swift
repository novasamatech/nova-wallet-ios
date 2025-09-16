import Foundation
@testable import novawallet

class StakingAnalyticsLocalSubscriptionFactoryStub {
    let weaklyAnalytics: [SubqueryRewardItemData]?

    init(weaklyAnalytics: [SubqueryRewardItemData]? = nil) {
        self.weaklyAnalytics = weaklyAnalytics
    }
}

extension StakingAnalyticsLocalSubscriptionFactoryStub: StakingAnalyticsLocalSubscriptionFactoryProtocol {
    func getWeaklyAnalyticsProvider(
        for _: AccountAddress,
        url _: URL
    ) -> AnySingleValueProvider<[SubqueryRewardItemData]> {
        let provider = SingleValueProviderStub(item: weaklyAnalytics)
        return AnySingleValueProvider(provider)
    }
}
