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
