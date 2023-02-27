import Foundation

struct ReferendumVoterLocal: Equatable {
    let accountId: AccountId
    let vote: ReferendumAccountVoteLocal
    let delegators: [GovernanceOffchainDelegation]

    init(accountId: AccountId, vote: ReferendumAccountVoteLocal, delegators: [GovernanceOffchainDelegation] = []) {
        self.accountId = accountId
        self.vote = vote
        self.delegators = delegators
    }
}
