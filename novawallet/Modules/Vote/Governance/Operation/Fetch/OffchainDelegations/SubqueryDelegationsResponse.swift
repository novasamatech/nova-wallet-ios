import Foundation

struct SubqueryDelegationsReponse: Decodable {
    struct Delegations: Decodable {
        let nodes: [Delegation]
    }

    struct Delegation: Decodable {
        let delegator: AccountAddress
        let delegation: SubqueryVotingResponse.RawVote
    }

    let delegations: Delegations
}
