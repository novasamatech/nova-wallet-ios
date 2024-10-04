import Foundation
import BigInt

struct GovernanceVoteValidatingParams {
    let assetBalance: AssetBalance?
    let referendum: ReferendumLocal?
    let newVote: ReferendumNewVote?
    let selectedConviction: ConvictionVoting.Conviction?
    let fee: ExtrinsicFeeProtocol?
    let votes: ReferendumAccountVotingDistribution?
    let assetInfo: AssetBalanceDisplayInfo
}

struct GovernanceVotePowerValidatingParams {
    let assetBalance: AssetBalance?
    let votePower: VotingPowerLocal?
    let assetInfo: AssetBalanceDisplayInfo
}

struct GovernanceVoteBatchValidatingParams {
    let assetBalance: AssetBalance?
    let referendums: [ReferendumLocal]?
    let votes: ReferendumAccountVotingDistribution?
    let newVotes: [ReferendumNewVote]?
    let fee: ExtrinsicFeeProtocol?
    let assetInfo: AssetBalanceDisplayInfo

    var maxAmount: BigUInt? {
        newVotes?
            .max(by: { $0.voteAction.amount() < $1.voteAction.amount() })?
            .voteAction
            .amount()
    }
}

struct GovMaxAmountValidatingParams {
    let assetBalance: AssetBalance?
    let votingAmount: BigUInt?
    let fee: ExtrinsicFeeProtocol?
    let assetInfo: AssetBalanceDisplayInfo
}
