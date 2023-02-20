import Foundation
import BigInt

struct GovernanceUndelegateValidatingParams {
    let assetBalance: AssetBalance?
    let selectedTracks: Set<TrackIdLocal>
    let delegateId: AccountId
    let fee: BigUInt?
    let votes: ReferendumAccountVotingDistribution?
    let assetInfo: AssetBalanceDisplayInfo
}
