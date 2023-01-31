import Foundation
import BigInt

struct SubqueryVotingResponse: Decodable {
    struct SplitAbstainVote: Decodable {
        let ayeAmount: String
        let nayAmount: String
        let abstainAmount: String
    }

    struct SplitVote: Decodable {
        let ayeAmount: String
        let nayAmount: String
    }

    struct StandardVote: Decodable {
        let aye: Bool
        let vote: RawVote
    }

    struct DelegateCastingVoting: Decodable {
        let referendumId: String
        let voter: AccountAddress
        let standardVote: StandardVote?
    }

    struct RawVote: Decodable {
        let amount: String
        let conviction: String
    }

    struct DelegatorVoting: Decodable {
        let vote: RawVote
        let parent: DelegateCastingVoting
    }

    struct DelegatorVotings: Decodable {
        let nodes: [DelegatorVoting]
    }

    struct CastingVoting: Decodable {
        let referendumId: String
        let standardVote: StandardVote?
        let splitVote: SplitVote?
        let splitAbstainVote: SplitAbstainVote?
    }

    struct CastingVotings: Decodable {
        let nodes: [CastingVoting]
    }

    struct CastingAndDelegatorResponse: Decodable {
        let delegatorVotings: DelegatorVotings
        let castingVotings: CastingVotings
    }

    struct CastingResponse: Decodable {
        let castingVotings: CastingVotings
    }
}

extension ConvictionVoting.Conviction {
    init(subqueryConviction: String) {
        switch subqueryConviction {
        case "None":
            self = .none
        case "Locked1x":
            self = .locked1x
        case "Locked2x":
            self = .locked2x
        case "Locked3x":
            self = .locked3x
        case "Locked4x":
            self = .locked4x
        case "Locked5x":
            self = .locked5x
        case "Locked6x":
            self = .locked6x
        default:
            self = .unknown
        }
    }
}

extension ConvictionVoting.AccountVoteStandard {
    init?(subqueryVote: SubqueryVotingResponse.StandardVote) {
        guard let balance = BigUInt(subqueryVote.vote.amount) else {
            return nil
        }

        let conviction = ConvictionVoting.Conviction(subqueryConviction: subqueryVote.vote.conviction)

        let vote = ConvictionVoting.Vote(aye: subqueryVote.aye, conviction: conviction)

        self.init(vote: vote, balance: balance)
    }
}

extension ConvictionVoting.AccountVoteSplit {
    init?(subqueryVote: SubqueryVotingResponse.SplitVote) {
        guard let ayeAmount = BigUInt(subqueryVote.ayeAmount) else {
            return nil
        }

        guard let nayAmount = BigUInt(subqueryVote.nayAmount) else {
            return nil
        }

        self.init(aye: ayeAmount, nay: nayAmount)
    }
}

extension ReferendumAccountVoteLocal {
    init?(subqueryStandardVote: SubqueryVotingResponse.StandardVote) {
        guard let standardVote = ConvictionVoting.AccountVoteStandard(subqueryVote: subqueryStandardVote) else {
            return nil
        }

        self = .standard(standardVote)
    }

    init?(subquerySplitVote: SubqueryVotingResponse.SplitVote) {
        guard let splitVote = ConvictionVoting.AccountVoteSplit(subqueryVote: subquerySplitVote) else {
            return nil
        }

        self = .split(splitVote)
    }
}
