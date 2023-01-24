import Foundation

struct SubqueryDelegateStatsResponse: Decodable {
    struct Delegates: Decodable {
        let totalCount: UInt64
        let nodes: [Delegate]
    }

    struct Delegate: Decodable {
        let accountId: AccountAddress
        let delegators: UInt64
        let delegatorVotes: String
        let delegateVotes: DelegateVotes
    }

    struct DelegateVotes: Decodable {
        let totalCount: UInt64
    }

    let delegates: Delegates
}
