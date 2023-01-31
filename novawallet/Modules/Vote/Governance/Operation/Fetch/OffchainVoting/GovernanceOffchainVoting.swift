import Foundation
import BigInt

struct GovernanceOffchainVoting {
    enum VoteType {
        case direct(ReferendumAccountVoteLocal)
        case delegated(DelegateVote)
    }

    struct DelegateVote {
        let delegateAddress: AccountAddress
        let delegateVote: ConvictionVoting.AccountVoteStandard
        let delegatorPower: DelegatorPower
    }

    struct DelegatorPower {
        let balance: BigUInt
        let conviction: ConvictionVoting.Conviction
    }

    let address: AccountAddress
    let votes: [ReferendumIdLocal: VoteType]

    func getAllDirectVotes() -> GovernanceOffchainVotes {
        votes.compactMapValues { voteType in
            switch voteType {
            case let .direct(vote):
                return vote
            case .delegated:
                return nil
            }
        }
    }

    func insertingDirect(
        vote: ReferendumAccountVoteLocal,
        referendumId: ReferendumIdLocal
    ) -> GovernanceOffchainVoting {
        var newVotes = votes
        newVotes[referendumId] = .direct(vote)

        return .init(address: address, votes: newVotes)
    }

    func insertingDelegated(vote: DelegateVote, referendumId: ReferendumIdLocal) -> GovernanceOffchainVoting {
        var newVotes = votes
        newVotes[referendumId] = .delegated(vote)

        return .init(address: address, votes: newVotes)
    }
}

extension GovernanceOffchainVoting {
    func insertingSubquery(castingVote: SubqueryVotingResponse.CastingVoting) -> GovernanceOffchainVoting {
        guard let referendumId = ReferendumIdLocal(castingVote.referendumId) else {
            return self
        }

        if let standardVote = castingVote.standardVote {
            if let vote = ReferendumAccountVoteLocal(subqueryStandardVote: standardVote) {
                return insertingDirect(vote: vote, referendumId: referendumId)
            }
        } else if let splitVote = castingVote.splitVote {
            if let vote = ReferendumAccountVoteLocal(subquerySplitVote: splitVote) {
                return insertingDirect(vote: vote, referendumId: referendumId)
            }
        }

        return self
    }

    func insertingSubquery(delegatedVote: SubqueryVotingResponse.DelegatorVoting) -> GovernanceOffchainVoting {
        guard let referendumId = ReferendumIdLocal(delegatedVote.parent.referendumId) else {
            return self
        }

        guard
            let standardVote = delegatedVote.parent.standardVote,
            let delegateVote = ConvictionVoting.AccountVoteStandard(subqueryVote: standardVote) else {
            return self
        }

        let delegatorConviction = ConvictionVoting.Conviction(subqueryConviction: delegatedVote.vote.conviction)

        guard let delegatorBalance = BigUInt(delegatedVote.vote.amount) else {
            return self
        }

        let delegatorPower = DelegatorPower(balance: delegatorBalance, conviction: delegatorConviction)

        let vote = DelegateVote(
            delegateAddress: delegatedVote.parent.voter,
            delegateVote: delegateVote,
            delegatorPower: delegatorPower
        )

        return insertingDelegated(vote: vote, referendumId: referendumId)
    }
}
