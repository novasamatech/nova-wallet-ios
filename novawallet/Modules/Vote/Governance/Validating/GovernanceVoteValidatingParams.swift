import Foundation
import BigInt

struct GovernanceVoteValidatingParams {
    let assetBalance: AssetBalance?
    let referendum: ReferendumLocal?
    let newVote: ReferendumNewVote?
    let fee: BigUInt?
    let votes: ReferendumAccountVotingDistribution?
    let assetInfo: AssetBalanceDisplayInfo
}
