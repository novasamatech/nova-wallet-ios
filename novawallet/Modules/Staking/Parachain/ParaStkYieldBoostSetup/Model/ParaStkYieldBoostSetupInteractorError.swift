import Foundation
import BigInt

enum ParaStkYieldBoostSetupInteractorError: Error {
    case rewardCalculatorFetchFailed
    case identitiesFetchFailed
    case balanceSubscriptionFailed(_ internalError: Error)
    case priceSubscriptionFailed(_ internalError: Error)
    case delegatorSubscriptionFailed(_ internalError: Error)
    case scheduledRequestsSubscriptionFailed(_ internalError: Error)
    case yieldBoostTaskSubscriptionFailed(_ internalError: Error)
    case yieldBoostParamsFailed(_ reason: Error, stake: BigUInt, collator: AccountId)
}
