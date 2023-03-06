import Foundation

struct SubqueryDelegateDetailsResponse: Decodable {
    struct Delegates: Decodable {
        let nodes: [Details]
    }

    struct Details: Decodable {
        let accountId: AccountAddress
        let delegators: UInt64
        let delegatorVotes: String
        let allVotes: Total
        let recentVotes: Total
    }

    struct Total: Decodable {
        let totalCount: UInt64
    }

    let delegates: Delegates
}
