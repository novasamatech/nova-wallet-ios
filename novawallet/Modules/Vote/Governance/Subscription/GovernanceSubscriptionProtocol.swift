import Foundation

typealias ReferendumSubscriptionResult = Result<CallbackStorageSubscriptionResult<ReferendumLocal>, Error>

typealias ReferendumVotesSubscriptionResult = Result<
    CallbackStorageSubscriptionResult<[ReferendumIdLocal: ReferendumAccountVoteLocal]>,
    Error
>

protocol GovernanceSubscriptionFactoryProtocol {
    func subscribeToReferendum(
        _ target: AnyObject,
        referendumIndex: UInt,
        notificationClosure: @escaping (ReferendumSubscriptionResult?) -> Void
    )

    func unsubscribeFromReferendum(_ target: AnyObject, referendumIndex: ReferendumIdLocal)

    func subscribeToAccountVotes(
        _ target: AnyObject,
        accountId: AccountId,
        notificationClosure: @escaping (ReferendumVotesSubscriptionResult?) -> Void
    )

    func unsubscribeFromAccountVotes(_ target: AnyObject, accountId: AccountId)
}
