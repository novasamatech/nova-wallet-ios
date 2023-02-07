import Foundation
import BigInt

struct GovernanceNewDelegation {
    let delegateId: AccountId
    let trackIds: Set<TrackIdLocal>
    let balance: BigUInt
    let conviction: ConvictionVoting.Conviction
}
