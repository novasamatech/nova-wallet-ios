import Foundation

struct ReferendumVoterLocal {
    let accountId: AccountId
    let vote: ReferendumAccountVoteLocal
    let delegators: [Delegator]

    struct Delegator {
        let address: AccountAddress
        let power: GovernanceOffchainVoting.DelegatorPower
    }

    init(accountId: AccountId, vote: ReferendumAccountVoteLocal, delegators: [ReferendumVoterLocal.Delegator] = []) {
        self.accountId = accountId
        self.vote = vote
        self.delegators = delegators
    }
}
