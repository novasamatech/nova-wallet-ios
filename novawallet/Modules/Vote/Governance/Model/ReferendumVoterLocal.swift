import Foundation
import BigInt

struct ReferendumVoterLocal: Equatable {
    let accountId: AccountId
    let vote: ReferendumAccountVoteLocal
    let delegators: [GovernanceOffchainDelegation]

    init(accountId: AccountId, vote: ReferendumAccountVoteLocal, delegators: [GovernanceOffchainDelegation] = []) {
        self.accountId = accountId
        self.vote = vote
        self.delegators = delegators
    }

    var delegatorsVotes: BigUInt {
        delegators.reduce(into: 0) {
            $0 += ($1.power.conviction.votes(for: $1.power.balance) ?? 0)
        }
    }
}
